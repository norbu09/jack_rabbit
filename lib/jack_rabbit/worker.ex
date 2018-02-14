defmodule JackRabbit.Worker do
  use GenServer
  require Logger

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  def init(config) do
    Logger.debug("Started a JackRabbit worker...")
    {:ok, %{config: config}}
  end
  
  def process(pid, config, job) do
    GenServer.call(pid, {:process, config, job})
  end

  def stop(pid) do
    GenServer.stop(pid)
  end



  @doc """
  Internal implementation below the fold
  --------------------------------------

  These are the tasks that map to the actual implementation of the calls
  """

  def handle_call({:process, _config, job}, _from, state) do
    # push it to a rabbit queue
    # {:ok, res} = JackRabbit.Rabbit.send(state.config.rabbit_pid, config, job)
    {:reply, job, state}
  end

end
