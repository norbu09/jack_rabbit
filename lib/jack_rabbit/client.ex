defmodule JackRabbit.Client do

  use GenServer
  require Logger

  def start_link do
    start_link(nil)
  end
  def start_link([], config) do
    start_link(config)
  end
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    with {:ok, r_conf} <- JackRabbit.Management.rabbit_config(),
         {:ok, r_pid}  <- JackRabbit.Rabbit.start_link(Map.merge(r_conf, %{name: config[:name], queue: config[:queue] || config[:name]})),
         {:ok, w_pid}  <- JackRabbit.WorkerSupervisor.start_link(),
         :ok           <- Logger.debug("Started JackRabbit client ..."),
      do: {:ok, %{config: config, rabbit_config: r_conf, rabbit_pid: r_pid, worker_pid: w_pid}}
  end

  def call(pid, config, job) do
    GenServer.call(pid, {:call, config, job})
  end

  def cast(pid, config, job) do
    GenServer.call(pid, {:cast, config, job})
  end

  def async(pid, config, job, callback) do
    GenServer.call(pid, {:async, config, job, callback})
  end

  def stop(_pid) do
    # GenServer.stop(pid)
    Logger.info("Should stop here really")
  end


  @doc """
  Internal implementation below the fold
  --------------------------------------

  These are the tasks that map to the actual implementation of the calls
  """

  def handle_call({:call, config, job}, _from, state) do
    res = JackRabbit.Rabbit.call(state.rabbit_pid, config, job)
    {:reply, res, state}
  end

  def handle_call({:cast, config, job}, _from, state) do
    res = JackRabbit.Rabbit.cast(state.rabbit_pid, config, job)
    {:reply, res, state}
  end

  def handle_call({:async, config, job, _callback}, _from, state) do
    # TODO: this still needs actual async handling
    res = JackRabbit.Rabbit.call(state.rabbit_pid, config, job)
    {:reply, res, state}
  end

  def terminate(reason, _state) do
    # add any teardown stuff here
    {:stop, reason}
  end

end
