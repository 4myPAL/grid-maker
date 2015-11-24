defmodule GridMaker do
  use Application
  alias Decimal, as: D

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:grid_maker, :grid)

    config = %{ config | min: D.new(config.min) }
    config = %{ config | max: D.new(config.max) }
    config = %{ config | unit: D.new(config.unit) }
    config = %{ config | unit_vol: D.new(config.unit_vol) }
    config = %{ config | point: D.new(config.point) }

    children = [
      worker(GridMaker.Worker, [config, :bid], id: :bid_worker),
      worker(GridMaker.Worker, [config, :ask], id: :ask_worker),
      worker(GridMaker.Ticker, [config])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GridMaker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
