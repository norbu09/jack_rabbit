defmodule JackRabbit.WorkerSupervisor do
  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Start a worker process and add it to supervision
  def add_worker(config) do
    DynamicSupervisor.start_child(JackRabbit.Worker, config)
  end

  # Terminate a worker process and remove it from supervision
  def remove_worker(pid) do
    DynamicSupervisor.terminate_child(JackRabbit.Worker, pid)
  end

end
