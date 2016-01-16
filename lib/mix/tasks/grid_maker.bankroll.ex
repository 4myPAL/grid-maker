defmodule Mix.Tasks.GridMaker.Bankroll do
  use Mix.Task
  alias Decimal, as: D

  @shortdoc "Calculate grid bankroll"

  @moduledoc """
  Calculate grid trading bankroll.
      mix grid_maker.bankroll cells gap volume price
  """
  def run([cells, gap, volume, price]) do
    cells  = D.new(cells) |> D.div_int(D.new(2))
    gap    = D.new gap
    volume = D.new volume
    price  = D.new price

    cells_int = (cells |> D.to_string |> String.to_integer)

    min_price = price |> D.sub(D.mult(gap, cells))
    max_price = price |> D.add(D.mult(gap, cells))

    bid_bankroll = Enum.reduce cells_int..1, D.new(0), fn
      (x, acc) ->
        p = D.sub(price, D.mult(gap, D.new(x)))
        b = D.mult(p, volume)
        Mix.shell.info " - BID PRICE: #{p} VOLUME: #{volume} BANKROLL: #{b}"
        D.add(acc, b)
    end

    Mix.shell.info " - ================================================================================="

    ask_bankroll = Enum.reduce 1..cells_int, D.new(0), fn
      (x, acc) ->
        p = D.add(price, D.mult(gap, D.new(x)))
        b = D.mult(p, volume)
        Mix.shell.info " - ASK PRICE: #{p} VOLUME: #{volume} BANKROLL: #{b}"
        D.add(acc, b)
    end

    Mix.shell.info "CELLS #{cells} GAP #{gap} VOLUME #{volume} price #{price} MIN #{min_price} MAX #{max_price}"
    Mix.shell.info "BID #{bid_bankroll} ASK #{ask_bankroll} (V: #{D.mult(volume, cells)} #{D.mult(D.mult(volume, cells), price)})"
  end
end
