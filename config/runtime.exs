import Config

if config_env() == :prod do
  port = String.to_integer(System.get_env("PORT") || "80")

  secret_key_base =
    case System.get_env("SECRET_KEY_BASE") do
      nil ->
        IO.warn(
          "SECRET_KEY_BASE not set; generated an ephemeral secret. Sessions and " <>
            "LiveView sockets won't survive a restart or span multiple instances.",
          []
        )

        Base.encode64(:crypto.strong_rand_bytes(48))

      value ->
        value
    end

  config :metrics_demo, MetricsDemoWeb.Endpoint,
    server: true,
    http: [ip: {0, 0, 0, 0}, port: port],
    check_origin: false,
    secret_key_base: secret_key_base
end
