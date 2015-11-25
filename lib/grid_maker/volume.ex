require Logger

defmodule GridMaker.Volume do
  use GenServer
  alias Decimal, as: D

  def fetch(scope) do
  end
  
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, [name: __MODULE__])
  end

  def handle_cast({:fetch, scope}, state) do
    {:noreply, state}
  end

  @doc ~S"""
  ## Examples

      iex> GridMaker.Volume.generate(Decimal.new(55), 5) |> GridMaker.Volume.sum
      #Decimal<275.00>

      iex> GridMaker.Volume.generate(Decimal.new(33), 7) |> GridMaker.Volume.sum
      #Decimal<231.00>

  """
  def generate(unit_volume, unit_size, precision \\ 2) when is_integer(unit_size) do
    volume = D.mult(unit_volume, D.new(unit_size))
    seeds = for n <- 1..unit_size, do: :random.uniform(1000)
    sum = seeds |> Enum.sum |> D.new
    volumes = for seed <- seeds, do: D.round(D.mult(D.div(D.new(seed), sum), volume), precision, :down)

    bias = D.sub(volume, volumes |> sum)

    [h|t] = volumes
    [D.add(h, bias)] ++ t
  end

  def sum([], acc) do acc end
  def sum([h|t], acc \\ D.new(0)) do
    sum(t, D.add(h, acc))
  end
end

