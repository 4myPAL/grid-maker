use Mix.Config

config :peatio_client, host: "https://yunbi.com"

config :grid_maker, grid: %{
  volume: 55,
  scope: 100,
  unit: 0.04,
  price: 5.5,
  unit_size: 5,
  market: "ethcny"
}

config :logger, level: :info

config :grid_maker, key: "wADSdBSyqONPtnErVmkLl5YIf1i1F12Ex1YuGzGZ"
config :grid_maker, secret: "IBeSPnGYxy95QqY0tp9JHTopex7M9t4PflimLYxN"
