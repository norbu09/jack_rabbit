defmodule JackRabbit.ManagementWorker do
  use GenServer
  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    Logger.debug("Started JackRabbit management interface...")
    {:ok, %{config: config}}
  end
  
  def register(pid) do
    GenServer.call(pid, :register)
  end

  def deregister(pid) do
    GenServer.call(pid, :deregister)
  end

  def get_rabbit_config(pid) do
    GenServer.call(pid, :rabbit_config)
  end




  @doc """
  Internal implementation below the fold
  --------------------------------------

  These are the tasks that map to the actual implementation of the calls
  """

  def handle_call(:register, _from, state) do
    # register worker in Consul
    {:reply, {:ok, state.config}, state}
  end

  def handle_call(:deregister, _from, state) do
    # deregister worker from Consul
    {:reply, {:ok, state.config}, state}
  end

  def handle_call(:rabbit_config, _from, state) do
    {:reply, JackRabbit.Management.rabbit_config(state.config[:rabbit_config]), state}
  end
end
