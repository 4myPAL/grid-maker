require Logger

defmodule GridMaker.Worker do
  use GenServer
  alias Decimal, as: D

  @api :api
  @bigger D.new(1) 
  @zero D.new(0)

  def tick(ticker) do
    GenServer.cast(__MODULE__, {:tick, ticker})
  end
  
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, [name: __MODULE__])
  end

  def init(config) do
    config = Dict.put config, :ticker, :wait
    {:ok, config}
  end

  def handle_cast({:tick, ticker}, config = %{ticker: :wait}) do
    side_price_scope = config.unit |> D.mult(D.new(config.scope) |> D.div D.new(2))

    max = ticker.last |> D.add side_price_scope
    min = ticker.last |> D.sub side_price_scope

    config = config |> Dict.put(:min, min) |> Dict.put(:max, max)
    
    PeatioClient.cancel_all @api

    case price_to_point(ticker.last, config) do
      :error -> 
        Logger.warn "LAST #{D.to_string(ticker.last)} OUT OF SCOPE " <> 
                    "#{D.to_string(config.min)} - #{D.to_string(config.max)} !!!"

        {:noreply, %{ config | ticker: :wait }}
      point ->
        volumes = GridMaker.Volume.all |> List.flatten

        pfn = fn(n) -> D.add(config.min, D.mult(D.new(n), config.unit)) end
        prices = for n <- 1..(length volumes), do: pfn.(n)

        mapper = fn ({p, v}) -> {D.to_string(p), D.to_string(v)} end
        filter = fn ({p, _}) -> D.compare(p, @zero) |> D.equal? @bigger end

        {bid_orders, ask_orders} = Enum.zip(prices, volumes) |> Enum.split(point)
        bid_orders = bid_orders |> Enum.filter_map(filter, mapper)
        ask_orders = ask_orders |> Enum.map(mapper)

        Logger.info "LOW: #{inspect List.first(bid_orders)}"
        Logger.info "BID: #{inspect List.last(bid_orders)}"
        Logger.info "ASK: #{inspect List.first(ask_orders)}"
        Logger.info "HIG: #{inspect List.last(ask_orders)}"

        PeatioClient.bid @api, config.market, bid_orders
        PeatioClient.ask @api, config.market, ask_orders

        {:noreply, %{ config | ticker: ticker }}
    end
  end

  def terminate(reason, state) do
    PeatioClient.cancel_all @api
    {:shutdown, :ok}
  end

  def handle_cast({:tick, ticker}, state) do
    {:noreply, state}
  end

  defp price_to_point(price, %{min: min, max: max, unit: unit}) do
    case {D.compare(price, min), D.compare(max, price)} do
      {@bigger, @bigger} ->
        price |> D.sub(min) |> D.div_int(unit) |> D.to_string |> String.to_integer
      _ ->
        :error
    end
  end
end
