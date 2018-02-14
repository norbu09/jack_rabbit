# JackRabbit

JackRabbit is a robust, simple and fast way of writing RabbitMQ worker
processes. It does not imply any specific use of the data structure used in the
message and makes proper use of AMQP headers for routing, content types and so
on.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `jack_rabbit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jack_rabbit, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/jack_rabbit](https://hexdocs.pm/jack_rabbit).

