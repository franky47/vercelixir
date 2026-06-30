import Config

config :metrics_demo, MetricsDemoWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  pubsub_server: MetricsDemo.PubSub,
  render_errors: [formats: [html: MetricsDemoWeb.ErrorHTML], layout: false],
  live_view: [signing_salt: "metrics-lv"]

config :esbuild,
  version: "0.25.0",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :os_mon,
  start_cpu_sup: true,
  start_memsup: true,
  start_disksup: false,
  start_os_sup: false,
  system_memory_high_watermark: 0.99

config :phoenix, :json_library, Jason

config :logger, level: :info

if config_env() == :dev do
  config :metrics_demo, MetricsDemoWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4000],
    server: true,
    check_origin: false,
    debug_errors: true,
    secret_key_base: "devsecretdevsecretdevsecretdevsecretdevsecretdevsecretdevsecret12345678",
    watchers: [esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}]
end

if config_env() == :test do
  config :metrics_demo, MetricsDemoWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4002],
    server: false,
    secret_key_base: "testsecrettestsecrettestsecrettestsecrettestsecrettestsecret12345678"
end

if config_env() == :prod do
  config :metrics_demo, MetricsDemoWeb.Endpoint,
    cache_static_manifest: "priv/static/cache_manifest.json"
end
