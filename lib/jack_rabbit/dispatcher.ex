defmodule JackRabbit.Dispatcher do

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
    {:ok, mgmt_pid} = JackRabbit.Management.start_link([])
    {:ok, r_conf} = JackRabbit.Management.get_rabbit_config(mgmt_pid, config)
    {:ok, rabbit_pid} = JackRabbit.Rabbit.start_link(r_conf)
    JackRabbit.Management.register(mgmt_pid, config)
    Logger.debug("Started JackRabbit #{config[:name]} worker...")
    {:ok, %{config: config, rabbit_config: r_conf, mgmt: mgmt_pid, rabbit_pid: rabbit_pid}}
  end

  def call(config, job) do
    GenServer.call(__MODULE__, {:call, config, job})
  end

  def cast(config, job) do
    GenServer.call(__MODULE__, {:cast, config, job})
  end

  def async(config, job, callback) do
    GenServer.call(__MODULE__, {:async, config, job, callback})
  end




  @doc """
  Internal implementation below the fold
  --------------------------------------

  These are the tasks that map to the actual implementation of the calls
  """

  def handle_call({:call, config, job}, _from, state) do
    {:ok, pid} = JackRabbit.Worker.start_link(config)
    res = JackRabbit.Worker.process(pid, config, job)
    JackRabbit.Worker.stop(pid)
    {:reply, res, state}
  end

  def handle_call({:cast, config, job}, _from, state) do
    {:ok, pid} = JackRabbit.Worker.start_link(config)
    res = JackRabbit.Worker.process(pid, config, job)
    JackRabbit.Worker.stop(pid)
    {:reply, res, state}
  end

  def handle_call({:async, config, job, _callback}, _from, state) do
    {:ok, pid} = JackRabbit.Worker.start_link(config)
    res = JackRabbit.Worker.process(pid, config, job)
    JackRabbit.Worker.stop(pid)
    {:reply, res, state}
  end

  def terminate(reason, state) do
    JackRabbit.Management.deregister(state.mgmt_pid, state.config)
    {:stop, reason}
  end

end
