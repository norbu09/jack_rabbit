defmodule JackRabbit.Management do
  use GenServer
  require Logger

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  def init(_args) do
    Logger.debug("Started JackRabbit management interface...")
    {:ok, %{config: ""}}
  end
  
  def register(pid, config) do
    GenServer.call(pid, {:register, config})
  end

  def deregister(pid, config) do
    GenServer.call(pid, {:deregister, config})
  end

  def get_rabbit_config(pid, config) do
    GenServer.call(pid, {:rabbit_config, config})
  end




  @doc """
  Internal implementation below the fold
  --------------------------------------

  These are the tasks that map to the actual implementation of the calls
  """

  def handle_call({:register, config}, _from, state) do
    # register worker in Consul
    {:reply, config, state}
  end

  def handle_call({:deregister, config}, _from, state) do
    # deregister worker from Consul
    {:reply, config, state}
  end

  def handle_call({:rabbit_config, config}, _from, state) do
    # - get creds from vault
    # - get server connection from consul
    {:reply, config, state}
  end
end
