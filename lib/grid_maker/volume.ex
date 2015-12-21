require Logger

defmodule GridMaker.Volume do
  use GenServer
  alias Decimal, as: D

  def fetch(scope) do
    GenServer.call(__MODULE__, {:fetch, scope})
  end

  def all do
    GenServer.call(__MODULE__, :all)
  end
  
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, [name: __MODULE__])
  end

  # UNIT <- CELL <- GRID
  def init(config = %{scope: scope, unit_size: unit_size, volume: volume}) do
    cell_size = div(scope, unit_size)
    volumes = for _ <- 1..cell_size, do: generate(volume, unit_size)
    {:ok, %{volumes: volumes, config: config}}
  end

  def handle_call(:all, _, state = %{volumes: volumes}) do
    {:reply, volumes, state}
  end

  def handle_call({:fetch, range}, _, state = %{volumes: volumes, config: config}) do
    volumes = volumes |> refresh_volumes(range, config)
    range_volumes = volumes |> List.flatten |> Enum.slice(range)
    {:reply, range_volumes, %{state | volumes: volumes}}
  end

  defp refresh_volumes(volumes, range, %{volume: volume, unit_size: size}) do
    left = index_for_cell(range.first - 1, size) + 1
    right = index_for_cell(range.last + 1, size)
    
    case right - left do
      lenth when lenth > 0 ->
        n = for _ <- 1..lenth, do: generate(volume, size)
        {l, _} = Enum.split(volumes, left)
        {_, r} = Enum.split(volumes, right)
        l ++ n ++ r
      _ ->
        volumes
    end
  end

  defp index_for_cell(index, _size) when index <= 0 do -1 end
  defp index_for_cell(index, size) do (index - rem(index, size)) |> div(size) end

  @doc ~S"""
  Generate `unit_size` length and avg is `unit_volume` list.

  ## Examples

      iex> GridMaker.Volume.generate(Decimal.new(55), 5) |> GridMaker.Volume.sum
      #Decimal<275.00>

      iex> GridMaker.Volume.generate(Decimal.new(33), 7) |> GridMaker.Volume.sum
      #Decimal<231.00>

  """
  def generate(unit_volume, unit_size, precision \\ 4) when is_integer(unit_size) do
    volume = D.mult(unit_volume, D.new(unit_size))
    seeds = for _ <- 1..unit_size, do: :random.uniform(1000)
    sum = seeds |> Enum.sum |> D.new
    volumes = for seed <- seeds, do: D.round(D.mult(D.div(D.new(seed), sum), volume), precision, :down)

    bias = D.sub(volume, volumes |> sum)

    [h|t] = volumes
    [D.add(h, bias)] ++ t
  end

  @doc ~S"""
  Sum with Decimal list.

  ## Examples

      iex> [Decimal.new(3), Decimal.new(12.2)] |> GridMaker.Volume.sum
      #Decimal<15.2>

  """
  def sum([], acc) do acc end
  def sum([h|t], acc \\ D.new(0)) do
    sum(t, D.add(h, acc))
  end
end

