defmodule JackRabbit.Config.File do
  
  def rabbit_auth do
    user = System.get_env("RABBITMQ_USER") || Application.get_env(:jack_rabbit, :rabbit_user, "guest")
    pass = System.get_env("RABBITMQ_PASS") || Application.get_env(:jack_rabbit, :rabbit_pass, "guest")
    {:ok, %{"user" => user, "pass" => pass}}
  end

  def rabbit_conn do
    host = System.get_env("RABBITMQ_HOST") || Application.get_env(:jack_rabbit, :rabbit_host, "localhost")
    port = System.get_env("RABBITMQ_PORT") || Application.get_env(:jack_rabbit, :rabbit_port, 5672)
    {:ok, %{"host" => host, "port" => port}}
  end
end
