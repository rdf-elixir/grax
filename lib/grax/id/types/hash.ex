defmodule Grax.Id.Hash do
  use Grax.Id.Schema.Extension

  alias Grax.Id

  import Grax.Utils, only: [rename_keyword: 3]

  defstruct [:algorithm, :data_variable]

  defp __hash__(opts) do
    opts = extension_opt(__MODULE__, opts)
    template = Keyword.get(opts, :template, default_template(opts))

    quote do
      id_schema unquote(template), unquote(opts)
    end
  end

  defmacro hash({{:., _, [schema, property]}, _, []}) do
    __hash__(schema: schema, data: property)
  end

  defmacro hash(opts) do
    __hash__(opts)
  end

  defmacro hash({{:., _, [schema, property]}, _, []}, opts) do
    opts
    |> Keyword.put(:schema, schema)
    |> Keyword.put(:data, property)
    |> __hash__()
  end

  defmacro hash(schema, opts) do
    opts
    |> Keyword.put(:schema, schema)
    |> __hash__()
  end

  defp default_template(_opts), do: "{hash}"

  @impl true
  def init(id_schema, opts) do
    opts =
      opts
      |> rename_keyword(:algorithm, :hash_algorithm)
      |> rename_keyword(:data, :hash_data_variable)

    install(
      id_schema,
      %__MODULE__{
        algorithm: Id.Schema.option!(opts, :hash_algorithm, id_schema),
        data_variable: Keyword.fetch!(opts, :hash_data_variable)
      }
    )
  end

  @impl true
  def call(%{algorithm: algorithm, data_variable: variable}, _, variables, _) do
    with {:ok, data} <- get_data(variables, variable) do
      set_hash(variables, calculate(data, algorithm))
    end
  end

  def calculate(data, algorithm) do
    :crypto.hash(algorithm, data)
    |> Base.encode16()
    |> String.downcase()
  end

  defp get_data(variables, variable) do
    case variables[variable] do
      nil -> {:error, "no #{inspect(variable)} value for hashing present"}
      name -> {:ok, to_string(name)}
    end
  end

  defp set_hash(variables, hash),
    do: {:ok, Map.put(variables, :hash, hash)}
end
