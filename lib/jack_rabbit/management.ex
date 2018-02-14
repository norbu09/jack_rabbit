defmodule JackRabbit.Management do
  require Logger

  # use a dedicated auth backend or fall back to file/env config
  def rabbit_config() do
    rabbit_config(JackRabbit.Config.File)
  end
  def rabbit_config(nil) do
    rabbit_config(JackRabbit.Config.File)
  end
  def rabbit_config(config_mod) do
    {:ok, auth} = config_mod.rabbit_auth()
    {:ok, conn} = config_mod.rabbit_conn()
    {:ok, Map.merge(auth, conn)}
  end

  def worker() do
    worker(JackRabbit.Config.File)
  end
  def worker(nil) do
    worker(JackRabbit.Config.File)
  end
  def worker(config_mod) do
      # {JackRabbit.Dispatcher, %{name: "logger", processor: JackRabbit.Processor.Logger}},
    config_mod.get_worker()
  end
end
