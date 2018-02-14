defmodule JackRabbit.Processor.Logger do
  
  @behaviour JackRabbit.Worker
  require Logger

  def process(msg, _config) do
    Logger.info("MSG: #{inspect msg}")
  end
end
