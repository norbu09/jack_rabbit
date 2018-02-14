defmodule JackRabbit do
  @moduledoc """
  JackRabbit iexs a worker framework for RabbitMQ based worker
  """

  @doc """
  A `call` is blocking request that goes out to a worker and comes back with an
  answer.

  ## Examples

      iex> JackRabbit.call(%{queue: "foo", exchange: "bar", host: "localhost"}, %{"foo" => "bar"})
      {:ok, %{"bar" => "foo"}}

  """
  def call(config, message) do
    {:ok, pid} = JackRabbit.Client.start_link(%{})
    JackRabbit.Client.call(pid, config, message)
    JackRabbit.Client.stop(pid)
  end

  @doc """
  A `cast` is request that goes out to a worker and comes back with `:ok` or
  `:error` depending on the success of handing over the tast to the worker. It
  does not return any results from the worker.

  ## Examples

      iex> JackRabbit.cast(%{queue: "foo", exchange: "bar", host: "localhost"}, %{"foo" => "bar"})
      :ok

  """
  def cast(config, message) do
    {:ok, pid} = JackRabbit.Client.start_link(%{})
    JackRabbit.Client.cast(pid, config, message)
    JackRabbit.Client.stop(pid)
  end

  @doc """
  A `call_async` is non-blocking request that goes out to a worker and comes
  back with an answer. The answer then calls the function handed to the request
  as callback

  ## Examples

      iex> JackRabbit.call(%{queue: "foo", exchange: "bar", host: "localhost"}, %{"foo" => "bar"}, fun)
      :ok

  """
  def cast(config, message, callback) do
    JackRabbit.Dispatcher.async(config, message, callback)
  end
end
