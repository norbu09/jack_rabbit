defmodule JackRabbit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # read worker config
    {:ok, worker} = JackRabbit.Management.worker
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: JackRabbit.Worker.start_link(arg)
      supervisor(Task.Supervisor, [[name: JackRabbit.TaskSupervisor]])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JackRabbit.Supervisor]
    Supervisor.start_link(children ++ worker, opts)
  end
end
