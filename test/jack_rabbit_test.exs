defmodule JackRabbitTest do
  use ExUnit.Case
  doctest JackRabbit

  test "greets the world" do
    assert JackRabbit.hello() == :world
  end
end
