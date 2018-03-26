defmodule JackRabbit.Worker do

@callback process(pid :: pid, job :: term) ::
              {:ok, result :: term, new_state :: term}
              | {:error, reason :: term, new_state :: term}
end
