defmodule JackRabbit.Worker do

@callback process(args :: term, state :: term) ::
              {:ok, result :: term, new_state :: term}
              | {:error, reason :: term, new_state :: term}
end
