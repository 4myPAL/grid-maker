defmodule GridMaker do
  use Application
  alias Decimal, as: D

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:grid_maker, :grid) |> preprocess

    children = [
      worker(GridMaker.Volume, [config]),
      worker(GridMaker.Ticker, [config]),
      worker(GridMaker.Worker, [config])
    ]

    opts = [strategy: :one_for_one, name: GridMaker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp preprocess(config) do
    unit       = D.new(config.unit)
    price      = D.new(config.price)
    volume     = D.new(config.volume)
    
    side_price_scope = unit |> D.mult D.new(config.scope) |> D.div D.new(2)

    max = price |> D.add side_price_scope
    min = price |> D.sub side_price_scope

    %{config | unit: unit, price: price, volume: volume}
    |> Dict.put(:min, min)
    |> Dict.put(:max, max)
  end
end
