config :peatio_client, host: "HOST"

config :grid_maker, grid: %{
  volume: "VOLUME",
  scope: "SCOPE",
  unit: "UNIT",
  price: "PRICE",
  unit_size: "UNIT SIZE",
  market: "MARKET"
}

config :logger, level: :info

config :grid_maker, key: "KEY"
config :grid_maker, secret: "SECRET"
