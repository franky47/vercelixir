import Config

if config_env() == :prod do
  port = String.to_integer(System.get_env("PORT") || "80")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(48))

  config :metrics_demo, MetricsDemoWeb.Endpoint,
    server: true,
    http: [ip: {0, 0, 0, 0}, port: port],
    check_origin: false,
    secret_key_base: secret_key_base
end
