use Mix.Config

config :peatio_client, host: "https://stg.yunbi.com"

config :grid_maker, grid: %{
  volume: 5,
  scope: 30,
  unit: 0.04,
  price: 6.00,
  unit_size: 5,
  market: "ethcny"
}

config :logger, level: :info

config :grid_maker, key: "RKTCMD1kxoRLpf2ySGspROoRo9mj8wTauSxViZM2"
config :grid_maker, secret: "cxQUmvxXPKW7KwB5J2X4fqC4iEZfCYTTCfR7stQQ"
