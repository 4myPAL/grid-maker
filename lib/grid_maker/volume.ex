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

  def init(config = %{scope: scope, unit_size: unit_size, volume: volume}) do
    cell_size = div(scope, unit_size)
    volumes = for _ <- 1..cell_size, do: generate(volume, unit_size)
    {:ok, {volumes, config}}
  end

  def handle_call(:all, _, state = {volumes, _}) do
    {:reply, volumes, state}
  end

  def handle_call({:fetch, scope}, _, {volumes, config = %{unit_size: unit_size}}) do
    true = Range.range? scope

    first_index   = get_upper_with_unit_size(scope.first, unit_size) |> div(unit_size) |> - 1
    replace_count = get_lower_with_unit_size(scope.last,  unit_size) |> div(unit_size) |> - first_index

    volumes = update(first_index, replace_count, volumes, config)
    result = volumes |> List.flatten |> Enum.slice Range.new(scope.first - 1, scope.last - 1)

    {:reply, result, {volumes, config}}
  end

  defp update(_index, count, volumes, _config) when count < 1 do
    volumes
  end

  defp update(index, count, volumes, config = %{unit_size: unit_size, volume: volume}) do
    volumes = List.update_at volumes, index, fn(_) -> generate(volume, unit_size) end
    update(index + 1, count - 1, volumes, config)
  end

  defp get_lower_with_unit_size(number, unit_size) do
    number - rem(number, unit_size)
  end

  defp get_upper_with_unit_size(number, unit_size) do
    get_lower_with_unit_size(number, unit_size) + unit_size
  end

  @doc ~S"""
  Generate `unit_size` length and avg is `unit_volume` list.

  ## Examples

      iex> GridMaker.Volume.generate(Decimal.new(55), 5) |> GridMaker.Volume.sum
      #Decimal<275.00>

      iex> GridMaker.Volume.generate(Decimal.new(33), 7) |> GridMaker.Volume.sum
      #Decimal<231.00>

  """
  def generate(unit_volume, unit_size, precision \\ 2) when is_integer(unit_size) do
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

