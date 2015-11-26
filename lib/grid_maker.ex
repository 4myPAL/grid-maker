defmodule GridMaker do
  use Application
  alias Decimal, as: D

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:grid_maker, :grid) |> preprocess
    key = Application.get_env(:grid_maker, :key)
    secret = Application.get_env(:grid_maker, :secret)

    children = [
      worker(PeatioClient.Server, [:api, key, secret]),
      worker(GridMaker.Volume, [config]),
      worker(GridMaker.Ticker, [config]),
      worker(GridMaker.Worker, [config])
    ]

    opts = [strategy: :one_for_one, name: GridMaker.Supervisor, max_restarts: 1, max_seconds: 3]
    Supervisor.start_link(children, opts)
  end

  defp preprocess(config) do
    unit       = D.new(config.unit)
    price      = D.new(config.price)
    volume     = D.new(config.volume)

    %{config | unit: unit, price: price, volume: volume}
  end
end
