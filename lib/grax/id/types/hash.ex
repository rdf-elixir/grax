defmodule Grax.Id.Hash do
  use Grax.Id.Schema.Extension

  import Grax.Utils, only: [rename_keyword: 3]

  defstruct [:algorithm, :data_variable]

  defmacro hash(opts) do
    opts =
      __MODULE__
      |> extension_opt(opts)
      |> normalize_opts()

    template = Keyword.get(opts, :template, default_template(opts))

    quote do
      id_schema unquote(template), unquote(opts)
    end
  end

  defmacro hash(schema, opts) do
    opts = Keyword.put(opts, :schema, schema)

    quote do
      hash unquote(opts)
    end
  end

  defp normalize_opts(opts) do
    opts
    |> rename_keyword(:algorithm, :hash_algorithm)
    |> rename_keyword(:data, :hash_data_variable)
  end

  defp default_template(_opts), do: "{hash}"

  @impl true
  def init(id_schema, opts) do
    install(
      id_schema,
      %__MODULE__{
        algorithm: Keyword.fetch!(opts, :hash_algorithm),
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
      nil -> {:error, "name #{variable} for hashing not present"}
      name -> {:ok, to_string(name)}
    end
  end

  defp set_hash(variables, hash),
    do: {:ok, Map.put(variables, :hash, hash)}
end
