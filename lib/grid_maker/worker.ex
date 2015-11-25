require Logger

defmodule GridMaker.Worker do
  use GenServer
  alias Decimal, as: D

  def tick(ticker) do
    GenServer.cast(__MODULE__, {:tick, ticker})
  end
  
  def start_link(config) do
    Logger.info "#{inspect config}"
    GenServer.start_link(__MODULE__, config, [name: __MODULE__])
  end

  def handle_cast({:tick, ticker}, state) do
    {:noreply, state}
  end

  defp new_points(length) do
    length = length |> D.to_string |> String.to_integer
    for n <- 1..length, do: nil
  end
end
