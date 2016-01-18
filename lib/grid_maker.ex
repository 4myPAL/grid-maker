defmodule GridMaker do
  use Application
  alias Decimal, as: D

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    key = get_env(:grid_maker, :key)
    secret = get_env(:grid_maker, :secret)

    config = case get_env(:grid_maker, :grid, nil) do
      nil ->
        %{volume: get_env(:grid_maker, :volume) |> String.to_integer,
          scope: get_env(:grid_maker, :scope) |> String.to_integer,
          unit: get_env(:grid_maker, :unit) |> String.to_float,
          price: get_env(:grid_maker, :price) |> String.to_float,
          unit_size: get_env(:grid_maker, :unit_size) |> String.to_integer,
          market: get_env(:grid_maker, :market)
        }
      config -> config
    end |> preprocess

    host = get_env(:grid_maker, :host)

    children = [
      worker(PeatioClient.Entry, [:api, host, key, secret]),
      worker(GridMaker.Volume, [config]),
      worker(GridMaker.Ticker, [config]),
      worker(GridMaker.Worker, [config])
    ]

    opts = [strategy: :one_for_all, name: GridMaker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp preprocess(config) do
    unit       = D.new(config.unit)
    price      = D.new(config.price)
    volume     = D.new(config.volume)

    %{config | unit: unit, price: price, volume: volume}
  end

  defp get_env(app, key, default \\ :raise_error) do
    env_key = "#{app |> Atom.to_string |> String.upcase}_#{key |> Atom.to_string |> String.upcase}"
    case System.get_env(env_key) || Application.get_env(app, key, nil) do
      nil ->
        case default do
          :raise_error -> raise "Missing environment #{env_key}"
          _ -> default
        end
      val -> val
    end
  end
end
