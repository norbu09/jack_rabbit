defmodule JackRabbit.Processor.Logger do
  
  @behaviour JackRabbit.Worker
  require Logger

  def process(pid, meta, job) do
    Logger.debug("[CLIENT]{process} Got some data: #{inspect job}.")
    res = %{"Logger" => "ok"}
    Logger.debug("[CLIENT]{process} got meta: #{inspect meta}")
    GenServer.call(pid, {:client_response, res, meta})
    # GenServer.cast(pid, {:ack, meta.delivery_tag})
  end

end
