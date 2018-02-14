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
    with {:ok, mgmt_pid} <- JackRabbit.Management.start_link(config),
         {:ok, r_conf}   <- JackRabbit.Management.get_rabbit_config(mgmt_pid),
         {:ok, r_pid}    <- JackRabbit.Rabbit.start_link(Map.merge(r_conf, %{name: config[:name], queue: config[:queue] || config[:name]})),
         {:ok, w_pid}    <- JackRabbit.WorkerSupervisor.start_link(),
         :ok             <- Logger.debug("Started JackRabbit client ..."),
      do: {:ok, %{config: config, rabbit_config: r_conf, mgmt_pid: mgmt_pid, rabbit_pid: r_pid, worker_pid: w_pid}}
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

  def stop(pid) do
    GenServer.stop(pid)
  end


  @doc """
  Internal implementation below the fold
  --------------------------------------

  These are the tasks that map to the actual implementation of the calls
  """

  def handle_call({:call, config, job}, _from, state) do
    res = JackRabbit.Rabbit.call(state.rabbit_pid, config.queue, job)
    {:reply, res, state}
  end

  def handle_call({:cast, config, job}, _from, state) do
    {:ok, pid} = JackRabbit.WorkerSupervisor.add_worker(config)
    res = JackRabbit.Worker.process(pid, config, job)
    JackRabbit.WorkerSupervisor.remove_worker(pid)
    {:reply, res, state}
  end

  def handle_call({:async, config, job, _callback}, _from, state) do
    {:ok, pid} = JackRabbit.WorkerSupervisor.add_worker(config)
    res = JackRabbit.Worker.process(pid, config, job)
    JackRabbit.WorkerSupervisor.remove_worker(pid)
    {:reply, res, state}
  end

  def terminate(reason, state) do
    JackRabbit.Management.deregister(state.mgmt_pid)
    {:stop, reason}
  end

end
