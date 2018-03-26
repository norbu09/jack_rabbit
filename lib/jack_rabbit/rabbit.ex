defmodule JackRabbit.Rabbit do
  use GenServer
  use AMQP
  require Logger

  @timeout Application.get_env(:jack_rabbit, :timeout, 10000)

  def start_link(config) do
    {:ok, hostname} = :inet.gethostname
    queue = config[:queue] || "jr.client-" <> random_string()
    exchange = config[:exchange] || List.to_string(hostname)
    Logger.info("Starting worker on #{queue}")
    GenServer.start_link(__MODULE__, %{progress: "starting",
      queue: queue,
      name: String.to_atom(queue),
      error_queue: nil,
      consumer_tag: nil,
      connection: nil,
      channel: nil,
      client: true,
      default_exchange: exchange <> random_string(), 
      exchange: nil,
      config: config})
  end

  def init(state) do
    :ets.new(state.name, [:set, :named_table, :public])

    {:ok, conn} = Connection.open(Map.to_list(state.config))
    {:ok, chan} = Channel.open(conn)
    setup_queue(chan, state)

    # Limit unacknowledged messages to 10
    :ok = Basic.qos(chan, prefetch_count: 1)
    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(chan, state.queue)
    {:ok, %{state | channel: chan}}
  end

  def call(pid, conf, msg) do
    task = Task.Supervisor.async(JackRabbit.TaskSupervisor, fn ->
      receive do
        response ->
          Logger.debug("[CLIENT]{call} got response #{inspect response}")
          response
        after @timeout ->
          Logger.error("[CLIENT]{call} Did not get a response for this call: #{inspect msg}")
          {:error, :timeout}
        end
    end)
    {:ok, _id} = GenServer.call(pid, {:call, conf, msg, task.pid})
    Task.await(task, @timeout)
  end

  def cast(pid, queue, msg) do
    Logger.debug("[CLIENT] Got cast from JackRabbit - job: #{inspect msg}")
    GenServer.cast(pid, {:cast, queue, msg})
  end

  # ############################
  # internal functionality below
  ##############################

  # handle client request and send the message to the right queue
  def handle_call({:call, conf, job, task_pid}, _from, state) do
    # - need to generate a job ID
    # - store
    # FIXME the checksum should be a proper checksum at some stage
    meta = job["meta"] || %{}
    meta1 = meta
            |> Map.put("checksum", Map.get(meta, "checksum", random_string(25)))
            |> Map.put("reply_to", Map.get(meta, "reply_to", state.queue))
    job1 = Map.put(job, "meta", meta1)
    msg = "Got a call for #{conf.queue}"
    Logger.debug("{call} #{msg}")
    case Poison.encode(job1) do
      {:ok, json} ->
        case :ets.lookup(state.name, meta1["checksum"]) do
          [] -> 
            true = :ets.insert(state.name, {meta1["checksum"], task_pid})
            :ok = Basic.publish(state.channel, conf[:exchange] || "", conf.queue, json, [correlation_id: meta1["checksum"], reply_to: state.queue])
            Logger.warn("#{self() |> :erlang.pid_to_list}: -> #{conf.queue}")
            Logger.debug("{call} Sending #{inspect json} to #{conf.queue}")
            {:reply, {:ok, meta1["checksum"]}, %{state | progress: msg}}
          [{_id, pid}] when is_pid(pid) ->
            Logger.debug("Answering directly to PID")
            send(pid, job)
            {:reply, {:ok, meta1["checksum"]}, %{state | progress: msg}}
          error ->
            Logger.error("Matching error: got #{inspect error}")
            {:reply, {:error, error}, %{state | progress: error}}
        end
      error ->
        Logger.error("Could not JSON encode: #{inspect error}")
        {:reply, error, %{state | progress: error}}
    end
  end


  # General RabbitMQ handling
  #
  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, state) do
    spawn fn -> consume(state, tag, redelivered, payload) end
    {:noreply, state}
  end

  defp setup_queue(chan, state) do
    error_queue = "error.#{state.queue}"
    {:ok, _} = Queue.declare(chan, error_queue, durable: true)
    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} = Queue.declare(chan, state.queue,
                             durable: true,
                             arguments: [
                               {"x-dead-letter-exchange", :longstr, ""},
                               {"x-dead-letter-routing-key", :longstr, error_queue}
                             ]
                            )
    :ok = Exchange.fanout(chan, state.default_exchange, durable: true)
    :ok = Queue.bind(chan, state.queue, state.default_exchange)
  end

  # TODO: this needs to call the worker implementation
  defp consume(state, tag, _redelivered, json) do
    case Poison.decode(json) do
      {:ok, payload} ->
        Logger.info("Got a message: #{inspect payload}")
        # FIXME: only ack if message was a success
        :ok = Basic.ack state.channel, tag

        table = payload["meta"]["reply_to"] |> String.to_atom
        # Logger.debug("State: #{inspect state}")
        # Logger.debug("Table: ours: #{table} - all: #{inspect :ets.all()}")
        # Logger.debug("Elements: #{:ets.tab2list(table)}")
        case :ets.lookup(table, payload["meta"]["checksum"]) do
          [{_id, pid}] when is_pid(pid) ->
            Logger.debug("Answering directly to PID")
            send(pid, payload)
            {:reply, {:ok, payload}, state}
          error ->
            Logger.error("Matching error: got #{inspect error}")
            {:reply, {:error, error}, %{state | progress: error}}
        end
      error -> error
    end
  end

  #
  # helper functions
  #
  defp random_string(len \\ 8) do
    :crypto.strong_rand_bytes(len)
    |> Base.encode64 
    |> String.replace(~r/\W/, "", global: true)
  end
end
