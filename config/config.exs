import Config

config :metrics_demo,
  port: 4000,
  server: config_env() != :test

config :os_mon,
  start_cpu_sup: true,
  start_memsup: true,
  start_disksup: false,
  start_os_sup: false,
  system_memory_high_watermark: 0.99

config :logger, level: :info
