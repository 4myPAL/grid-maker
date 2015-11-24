defmodule GridMaker.Worker do
  use GenServer
  alias Decimal, as: D

  def tick(ticker) do
    GenServer.cast(pname(:ask), {:tick, ticker})
    GenServer.cast(pname(:bid), {:tick, ticker})
  end
  
  def start_link(config, side) do
    length = D.div_int(D.sub(config.max, config.min), config.point)

    config = Dict.put config, :length, length
    config = Dict.put config, :points, new_points(length)

    case side do
      :bid -> 
        config = Dict.put config, :side, :bid
        config = Dict.put config, :begin, config.min
      :ask ->
        config = Dict.put config, :side, :ask
        config = Dict.put config, :begin, config.max
    end

    GenServer.start_link(__MODULE__, config, [name: pname(side)])
  end

  def handle_cast({:tick, ticker}, state) do
    {:noreply, state}
  end

  defp pname(side) do
    "gride_maker:#{side}" |> String.to_atom
  end

  defp new_points(length) do
    length = length |> D.to_string |> String.to_integer
    for n <- 1..length, do: nil
  end
end
