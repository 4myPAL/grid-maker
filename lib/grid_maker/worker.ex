require Logger

defmodule GridMaker.Worker do
  use GenServer
  alias Decimal, as: D

  @api :api
  @bigger D.new(1) 
  @smaller D.new(-1) 
  @equal D.new(0) 
  @zero D.new(0)

  def tick(ticker) do
    GenServer.cast(__MODULE__, {:tick, ticker})
  end

  def check do
    GenServer.call(__MODULE__, :check)
  end
  
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, [name: __MODULE__])
  end

  def init(config) do
    config = ~w(ticker last prices orders support) 
              |> Enum.reduce config, fn
                (key, config) ->
                  Dict.put config, String.to_atom(key), nil
              end

    config = Dict.put config, :scope_range, Range.new(0, config.scope)

    {:ok, config}
  end

  def handle_call(:check, _, config) do
    {:reply, config, config}
  end

  def handle_cast({:tick, ticker}, config = %{ticker: nil}) do
    clean_history_orders

    config = preprocess(ticker, config)

    case to_bid_point(ticker.last, config) do
      bid_point_index when is_integer(bid_point_index) ->
        ask_point_index = bid_point_index + 1
        prices = fill_price(config.scope_range, config)
        volumes = GridMaker.Volume.all |> List.flatten

        {doubt, ask} = Enum.zip(prices, volumes) |> Enum.split(ask_point_index)
        bid = doubt |> Enum.filter_map(&filter_for_price/1, &map_for_api/1)
        ask = ask |> Enum.map(&map_for_api/1)

        padding = fill_padding(doubt, bid)
        orders  = padding ++ bid(config, bid) ++ ask(config, ask)

        support = %{bid: bid_point_index, ask: ask_point_index}

        Logger.warn "PADDING SIZE: #{length padding}"
        Logger.info "#{inspect List.first(bid)} -> " <>
                    "#{inspect List.last(bid)} | " <>
                    "#{inspect List.first(ask)} <- " <>
                    "#{inspect List.last(ask)}"
        Logger.info "SUPPORT_INDEX #{inspect support}"

        [last|_] = PeatioClient.trades(config.market)

        {:noreply, %{config | 
            last: last, 
            ticker: ticker, 
            prices: prices,
            orders: orders, 
            support: support
        }, 1000}
      :out_of_range -> 
        Logger.error "LAST #{ticker.last} OUT OF SCOPE #{config.min} TO #{config.max}"
        {:noreply, %{ config | ticker: :error }}
    end
  end

  def handle_info(:timeout, config) do
    trades = PeatioClient.trades(config.market, config.last.id)
    support = find_support(trades, config)

    last = case trades do
      [] -> config.last
      trades -> hd(trades)
    end

    if support != config.support do
      Logger.info("LAST TRADE ##{last.id} SUPPORT #{inspect support}")
    end

    case (support.bid + 1)..(support.ask - 1) do
      gap_bid..gap_ask when gap_bid > gap_ask ->
        {:noreply, %{config | last: last}, 1000}
      gap ->
        prices  = fill_price gap, config
        volumes = GridMaker.Volume.fetch gap

        bid_offset = support.ask - config.support.ask
        ask_offset = config.support.bid - support.bid

        {bid, ask} = Enum.zip(prices, volumes)
                     |> Enum.map(&map_for_api/1)
                     |> Enum.split(bid_offset)

        orders = bid(config, bid) ++ ask(config, ask)

        {lower, _}  = config.orders |> Enum.split(gap.first)
        {_, higher} = config.orders |> Enum.split(gap.last + 1)

        orders = lower ++ orders ++ higher

        support = %{ask: support.ask - ask_offset, bid: support.bid + bid_offset}
        Logger.info("NEW SUPPORT #{inspect support}")

        {:noreply, %{config | last: last, orders: orders, support: support}, 1000}
    end
  end

  defp preprocess(ticker, config) do
    side_price_scope = config.unit |> D.mult(D.new(config.scope) |> D.div D.new(2))

    max = ticker.last |> D.add side_price_scope
    min = ticker.last |> D.sub side_price_scope

    config |> Dict.put(:min, min) |> Dict.put(:max, max)
  end

  defp clean_history_orders do
    PeatioClient.cancel_all @api
  end

  defp fill_padding(l, r, fill \\ :padding) do
    case length(l) - length(r) do
      0 -> []
      size -> for _ <- 1..size, do: fill
    end
  end

  defp fill_price(range, config) do
    for p <- range, do: D.add(config.min, D.mult(D.new(p + 1), config.unit))
  end

  defp filter_for_price({p, _}) do
    D.compare(p, @zero) |> D.equal? @bigger
  end

  defp find_support([], %{support: support}) do support end
  defp find_support(trades, config) do
    range = trades |> Enum.reduce %{bid: nil, ask: nil}, fn
      (t, %{bid: nil, ask: nil}) ->
        %{bid: t, ask: t}
      (t, %{bid: l, ask: h}) ->
        case {D.compare(t.price, l.price), D.compare(t.price, h.price)} do
          {@smaller, _} ->
            %{bid: t, ask: h}
          {_, @bigger} ->
            %{bid: l, ask: t}
          _ ->
            %{bid: l, ask: h}
        end
    end

    # TODO: confirm to order with API
    bid_point = to_bid_point(range.bid.price, config)
    ask_point = to_ask_point(range.ask.price, config)

    {_, [bid_order|_]} = config.orders |> Enum.split(bid_point)
    {_, [ask_order|_]} = config.orders |> Enum.split(ask_point)

    bid_point = case PeatioClient.order(@api, bid_order.id) do
      %{state: :wait} -> bid_point
      _ -> bid_point - 1
    end

    ask_point = case PeatioClient.order(@api, ask_order.id) do
      %{state: :wait} -> ask_point
      _ -> ask_point + 1
    end

    %{bid: bid_point, ask: ask_point}
  end

  defp map_for_api({p, v}) do
    {D.to_string(p), D.to_string(v)}
  end

  defp ask(market, orders) do
    ask(market, orders, [])
  end

  defp ask(_, [], acc) do acc end
  defp ask(%{market: market}, orders, acc) do
    {h, t} = Enum.split(orders, 100)
    acc = acc ++ PeatioClient.ask(@api, market, orders)
    ask(%{market: market}, t, acc)
  end

  defp bid(market, orders) do
    bid(market, orders, [])
  end

  defp bid(_, [], acc) do acc end
  defp bid(%{market: market}, orders, acc) do
    {h, t} = Enum.split(orders, 100)
    acc = acc ++ PeatioClient.bid(@api, market, h)
    bid(%{market: market}, t, acc)
  end

  def to_ask_point(price, config) do
    to_bid_point(price, config, 1)
  end

  def to_bid_point(price, %{min: min, max: max, unit: unit, scope: scope}, offset \\ 0) do
    case {D.compare(price, D.add(min, unit)), D.compare(max, price)} do
      {@equal, _} -> 0
      {_, @equal} -> scope - 1
      {@bigger, @bigger} ->
        {point, check_bit} = price |> D.sub(min) |> D.div_rem(unit)

        case D.equal?(check_bit, @zero) do
          true -> String.to_integer(D.to_string(point)) - 1
          _ -> String.to_integer(D.to_string(point)) + offset - 1
        end
      _ ->
        :out_of_range
    end
  end
end
