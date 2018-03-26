defmodule JackRabbit.Processor.Logger do
  
  @behaviour JackRabbit.Worker
  require Logger

  def process(_pid, job) do
    Logger.debug("[CLIENT]{process} Got some data: #{inspect job}.")
    res = %{"Logger" => "ok"}
    {:client_response, res}
  end

end
