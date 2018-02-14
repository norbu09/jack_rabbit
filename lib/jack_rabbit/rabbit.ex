defmodule JackRabbit.Rabbit do
  use GenServer
  use AMQP
  require Logger

  @timeout Application.get_env(:jack_rabbit, :timeout, 10000)

  def start_link(config) do
    {:ok, hostname} = :inet.gethostname
    queue = config[:queue] || "jr.client-" <> random_string()
    Logger.info("Starting worker on #{queue}")
    GenServer.start_link(__MODULE__, %{progress: "starting",
      queue: queue,
      name: String.to_atom(queue),
      error_queue: nil,
      consumer_tag: nil,
      connection: nil,
      channel: nil,
      client: true,
      default_exchange: config[:exchange] || List.to_string(hostname),
      exchange: nil,
      config: config})
  end

  def init(state) do
    # check if the ETS table is created and create one if not
    case :ets.info(state.name) do
      :undefined ->
        :ets.new(state.name, [:set, :named_table, :public])
        connect(state)
      _info ->
        connect(state)
    end
  end

  def process(pid, meta, job) do
    Logger.debug("[CLIENT]{process} Got some data: #{inspect job}.")
    res = GenServer.call(pid, {:client_response, job, meta.correlation_id})
    Logger.debug("[CLIENT]{process} got meta: #{inspect meta}")
    GenServer.cast(pid, {:ack, meta.delivery_tag})
    res
  end

  def call(pid, queue, msg) do
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
    GenServer.call(pid, {:call, queue, msg, task.pid})
    Task.await(task, @timeout)
  end

  def cast(pid, queue, msg) do
    # Logger.debug("[CLIENT] Got cast from JackRabbit - job: #{inspect msg}")
    GenServer.cast(pid, {:cast, queue, msg})
  end

  ### internal call handling

  def handle_call({:call, queue, job, task}, _from, state) do
    # - need to generate a job ID
    # - store
    # FIXME the checksum should be a proper checksum at some stage
    meta = job["meta"] || %{}
    meta1 = meta
            |> Map.put("checksum", Map.get(meta, "checksum", random_string(25)))
            |> Map.put("reply_to", Map.get(meta, "reply_to", state.queue))

    job1 = Map.put(job, "meta", meta1)
    msg = "Got a call for #{queue}"
    Logger.debug("{call} #{msg}")
    case Poison.encode(job1) do
      {:ok, json} ->
        :ets.insert(state.name, {meta1["checksum"], task})
        :ok = AMQP.Basic.publish(state.channel, "", queue, json, [correlation_id: meta1["checksum"], reply_to: state.queue])
      Logger.warn("#{self() |> :erlang.pid_to_list}: -> #{queue}")
        Logger.debug("{call} Sending #{inspect json} to #{queue}")
        {:reply, {:ok, meta1["checksum"]}, %{state | progress: msg}}
      error ->
        {:reply, error, %{state | progress: error}}
    end
  end

  def handle_call({:client_response, res, tag}, _from, state) do
    cli_res = case :ets.lookup(state.name, tag) do
      [{_id, pid}] ->
        :ets.delete(state.name, tag)
        Logger.debug("{client_response} Responding to #{inspect pid} with #{inspect res}")
        send(pid, res)
        Logger.debug("{client_response} acking message")
        res
      _ ->
        Logger.debug("{client_response} nothing in ETS for #{tag}")
        res
    end
    msg = "Got a response for call with checksum #{tag}"
    {:reply, cli_res, %{state | progress: msg}}
  end

  # catch all for unknown calls
  def handle_call(request, from, state) do
    Logger.error("Got unhandeled call from #{inspect from} with payload: #{inspect request}")
    {:reply, :ok, state}
  end

  def handle_cast({:error, error, thing}, state) do
    tag = tag(thing)
    msg = "Got an error while processing: #{inspect error}"
    Logger.warn(msg)
    # send the error back to the client
    [{tag, {meta, _payload}}] = :ets.lookup(state.name, tag)
    Logger.debug("{error} Got meta from ETS #{inspect meta}")
    client(meta.reply_to, %{"error" => error}, meta.correlation_id)
    Logger.debug("{error} Sent response off to #{meta.reply_to}")
    # TODO decide if we want the error queue handling or not
    AMQP.Basic.reject state.channel, tag, requeue: false
    :ets.delete(state.name, tag)
    {:noreply, %{state | progress: msg}}
  end
  def handle_cast({:ack, tag}, state) do
    msg = "Got a ack for #{tag} on #{inspect state.channel}<"
    AMQP.Basic.ack state.channel, tag
    Logger.debug(msg)
    {:noreply, %{state | progress: msg}}
  end
  def handle_cast({:ok, :ack, thing}, state) do
    tag = tag(thing)
    msg = "Got a ack for #{tag}"
    AMQP.Basic.ack state.channel, tag
    :ets.delete(state.name, tag)
    Logger.debug(msg)
    {:noreply, %{state | progress: msg}}
  end
  def handle_cast({:ok, reply, thing}, state) do
    tag = tag(thing)
    msg = "Got a response for tag ##{tag}"
    Logger.debug("#{msg}")
    [{tag, {meta, _payload}}] = :ets.lookup(state.name, tag)
    Logger.debug("{ok} Got meta from ETS #{inspect meta}")
    client(meta.reply_to, reply, meta.correlation_id)
    Logger.debug("{ok} Sent response off to #{meta.reply_to}")
    AMQP.Basic.ack state.channel, tag
    Logger.debug("{ok} ACK message in RabbitMQ")
    :ets.delete(state.name, tag)
    Logger.debug("{ok} cleanup ETS")
    {:noreply, %{state | progress: msg}}
  end

  def handle_cast({:cast, queue, job}, state) do
    meta = job["meta"] || %{}
    corr_id = Map.get(meta, "checksum", random_string(25))
    handle_cast({:cast, queue, job, corr_id}, state)
  end
  def handle_cast({:cast, queue, job, corr_id}, state) do
    # - need to generate a job ID
    # - store
    # FIXME the checksum should be a proper checksum at some stage
    meta = job["meta"] || %{}
    meta1 = meta
            |> Map.put("checksum", corr_id)
            |> Map.put("reply_to", Map.get(meta, "reply_to", state.queue))

    job1 = Map.put(job, "meta", meta1)
    msg = "Got a call for #{queue}"
    Logger.debug("#{msg}")
    case Poison.encode(job1) do
      {:ok, json} ->
        res = AMQP.Basic.publish(state.channel, "", queue, json, [correlation_id: meta1["checksum"], reply_to: state.queue])
      Logger.warn("#{self() |> :erlang.pid_to_list}: -> #{queue}")
        Logger.debug("{cast} Sending #{inspect json} to #{queue}")
        Logger.debug("{cast} and got #{inspect res}")
      error -> error
    end
    {:noreply, %{state | progress: msg}}
  end

  def handle_cast(:stop, state) do
    AMQP.Queue.unsubscribe(state.channel, state.consumer_tag)
    AMQP.Channel.close(state.channel)
    AMQP.Connection.close(state.connection)
    msg = "Connection closed - waiting for ack"
    Logger.info(msg)
    {:noreply, %{state | progress: msg}}
  end
  # catch all for unknown casts
  def handle_cast(request, state) do
    Logger.error("Got unhandeled cast with payload: #{inspect request}")
    {:noreply, state}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
    msg = "[#{consumer_tag}]: Got registration"
    Logger.debug(msg)
    {:noreply, %{state | progress: msg}}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, state) do
    msg = "[#{consumer_tag}]: Consumer got cancelled - stopping"
    Logger.warn(msg)
    {:stop, :got_cancel,  %{state | progress: msg}}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, state) do
    msg = "[#{consumer_tag}]: Got cancellation - stopping"
    Logger.debug(msg)
    {:stop, :normal, %{state | progress: msg}}
  end

  def handle_info({:basic_deliver, payload, meta}, state) do
    Logger.debug("{basic_deliver} Message: #{inspect meta}")
    Logger.debug("{basic_deliver} State: #{inspect state}")
    case Poison.decode(payload) do
      {:ok, terms} ->
        Logger.debug("Got valid JSON, processing message with #{__MODULE__}: #{inspect terms}")
        :ets.insert(state.name, {meta.delivery_tag, {meta, payload}})
        # TODO: this should be a supervised task that returns instantly to not block this GenServer
        # {:ok, pid} = JackRabbit.WorkerSupervisor.add_worker(config)
        # res = JackRabbit.Worker.process(pid, config, job)
        # JackRabbit.WorkerSupervisor.remove_worker(pid)
        spawn_link(state.config.processor, :process, [meta, terms])
      error ->
        Logger.warn("Got malformed JSON: #{inspect error}")
        AMQP.Basic.reject state.channel, meta.delivery_tag, requeue: false
    end
    {:noreply, %{state | progress: "dispatched #{meta.delivery_tag}"}}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    {:ok, state1} = connect(state)
    {:noreply, state1}
  end

  # catch all for unknown info calls
  def handle_info(request, state) do
    Logger.error("Got unhandeled info call with payload: #{inspect request}")
    {:noreply, state}
  end

  def format_status(_reason, [ _pdict, state ]) do
    # TODO add ETS stats here
    [data: [{'State', "My current state is '#{inspect state}'"}]]
  end

  def terminate(reason, _state) do
    Logger.warn("Terminating: #{inspect reason}")
    :ok
  end

  defp client(queue, msg, correlation_id) do
    Logger.debug("{client} Sending message to #{queue}")
    GenServer.cast(self(), {:cast, queue, msg, correlation_id})
  end

  defp tag(thing) when is_map(thing) do
    thing.delivery_tag
  end
  defp tag(thing) when is_binary(thing) do
    thing
  end
  defp tag(thing) do
    Logger.error("Got an unhandled thing: #{inspect thing}")
  end

  defp connect(state) do
    error_queue = "error.#{state.queue}"
    reply_queue = "reply.#{state.queue}-" <> random_string(10)
    Logger.debug("Config: #{inspect state}")
    case AMQP.Connection.open(Map.to_list(state.config)) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = AMQP.Channel.open(conn)
        # Limit unacknowledged messages to 10
        AMQP.Basic.qos(chan, prefetch_count: 10)
        AMQP.Queue.declare(chan, reply_queue, [durable: false, exclusive: true])
        AMQP.Queue.declare(chan, error_queue, durable: true)
        # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
        case state.config[:queue] do # if called without queue we have a temporary dynamic queue
          nil ->
            AMQP.Queue.declare(chan, state.queue, ["auto-delete": true])
          queue ->
            AMQP.Queue.declare(chan, queue, durable: true,
                               arguments: [{"x-dead-letter-exchange", :longstr, ""},
                                           {"x-dead-letter-routing-key", :longstr, error_queue}])
        end
        case state[:exchange] do
          nil -> 
            AMQP.Exchange.direct(chan, state.default_exchange, durable: true)
          exchange -> Logger.info("Exchange #{exchange} already defined")
        end
        AMQP.Queue.bind(chan, state.queue, state.default_exchange)
        {:ok, tag} = AMQP.Basic.consume(chan, state.queue)
        {:ok, %{state | channel: chan, connection: conn,
          consumer_tag: tag, error_queue: error_queue, exchange: state.default_exchange}}
      {:error, _} ->
        Logger.warn("Connection to RabbitMQ server is down - reconnecting in 10s")
        :timer.sleep(10000)
        connect(state)
    end
  end

  defp random_string(len \\ 8) do
    :crypto.strong_rand_bytes(len)
    |> Base.encode64 
    |> String.replace(~r/\W/, "", global: true)
  end

end
