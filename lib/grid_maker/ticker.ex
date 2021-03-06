require Logger

defmodule GridMaker.Ticker do
  use GenServer
  @refresh_interval 1000

  def start_link(%{market: market}) do
    state = %{market: market, refresh_interval: @refresh_interval}
    GenServer.start_link(__MODULE__, state, [name: __MODULE__])
  end

  def init(state = %{market: _, refresh_interval: refresh_interval}) do
    {:ok, state, refresh_interval}
  end

  def handle_info(_timeout, state) do
    refresh_ticker(state)
  end

  defp refresh_ticker(state = %{market: market, refresh_interval: _refresh_interval}) do
    PeatioClient.ticker(:api, market) |> GridMaker.Worker.tick
    {:noreply, state}
  end
end
