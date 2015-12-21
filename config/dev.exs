use Mix.Config

config :peatio_client, host: "https://stg.yunbi.com"

config :grid_maker, grid: %{
  volume: 0.08,
  scope: 300,
  unit: 1000,
  price: 557000,
  unit_size: 5,
  market: "btccny"
}

config :logger, level: :info

config :grid_maker, key: "kUi35OLqYxl0uEIxGeCDl0WcNAHetHok5x0lYnbq"
config :grid_maker, secret: "SrIkSWYzlU0MAszRna9tTjrZaeTnxxkS4xbKZPQ9"
