defmodule Mix.Tasks.GridMaker.Bankroll do
  use Mix.Task
  alias Decimal, as: D

  @zero D.new(0)

  @shortdoc "Calculate grid bankroll"

  @moduledoc """
  Calculate grid trading bankroll.
      mix grid_maker.bankroll cells gap volume price
  """
  def run(args = [min, max, gap, volume, price]) do
    [min, max, gap, volume, price] = for n <- args, do: D.new(n)

    gap_count = 
      D.sub(max, min)
      |> D.div(gap)
      |> D.round(0, :down)
      |> D.to_string(:normal)
      |> String.to_integer

    split_point =
      price 
      |> D.sub(min)
      |> D.div(gap)
      |> D.round(0, :down)
      |> D.to_string(:normal)
      |> String.to_integer

    Mix.shell.info "GAP #{gap} GAP_COUNT #{gap_count} SPLIT_POINT #{split_point} MIN #{min} MAX #{max}"
    Mix.shell.info "---------------------------------------------------------------------"

    grid = for n <- 1..gap_count do
      price = n |> D.new |> D.mult(gap) |> D.add(min)
      amount = price |> D.mult(volume)
      cell = %{price: price, volume: volume, amount: amount, side: :bid }

      if n > split_point, do: cell = %{cell | side: :ask}

      cell
    end

    bankroll = grid |> Enum.reduce(%{bid: @zero, ask: @zero}, fn
      (%{side: :ask, volume: volume}, bankroll) ->
        %{bankroll | ask: bankroll.ask |> D.add(volume)}
      (%{side: :bid, amount: amount}, bankroll) ->
        %{bankroll | bid: bankroll.bid |> D.add(amount)}
    end)

    Mix.shell.info "BID_BANKROLL #{bankroll.bid} ASK_BANKROLL #{bankroll.ask} ASK_ASSET #{bankroll.ask |> D.mult(price)}"
  end
end
