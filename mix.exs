defmodule JackRabbit.MixProject do
  use Mix.Project

  def project do
    [
      app: :jack_rabbit,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :amqp, :amqp_client],
      mod: {JackRabbit.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, ">= 0.2.2"},
      {:amqp_client, ">= 3.6.0"},
      {:poison, ">= 1.5.0"}
    ]
  end
end
