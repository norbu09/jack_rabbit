defmodule JackRabbit.Rabbit do
  use GenServer
  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    Logger.debug("Started JackRabbit rabbit interface...")
    {:ok, %{config: config}}
  end
  
  def send(pid, config, message) do
    GenServer.call(pid, {:send, config, message})
  end



  @doc """
  Internal implementation below the fold
  --------------------------------------

  These are the tasks that map to the actual implementation of the calls
  """

  def handle_call({:send, _config, message}, _from, state) do
    # send message off to rabbitMQ
    {:reply, message, state}
  end

end
