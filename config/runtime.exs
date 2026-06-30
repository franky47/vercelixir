import Config

if config_env() == :prod do
  port = String.to_integer(System.get_env("PORT") || "80")
  config :metrics_demo, port: port
end
