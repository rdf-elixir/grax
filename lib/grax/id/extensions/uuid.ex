defmodule Grax.Id.UUID do
  use Grax.Id.Schema.Extension

  alias Grax.Id
  alias Grax.Id.UrnNamespace

  alias Uniq.UUID

  import Grax.Utils, only: [rename_keyword: 3]

  defstruct [:version, :format, :namespace, :name_var]

  defp __uuid__(opts) do
    opts = extension_opt(__MODULE__, opts)
    template = Keyword.get(opts, :template, default_template(opts))

    quote do
      id_schema unquote(template), unquote(opts)
    end
  end

  defmacro uuid({{:., _, [schema, property]}, _, []}) do
    __uuid__(schema: schema, uuid_name_var: property)
  end

  defmacro uuid(opts) do
    __uuid__(opts)
  end

  defmacro uuid(schema, opts) do
    opts
    |> Keyword.put(:schema, schema)
    |> __uuid__()
  end

  Enum.each([1, 3, 4, 5], fn version ->
    name = String.to_atom("uuid#{version}")

    if version in [3, 5] do
      defmacro unquote(name)({{:., _, [schema, uuid_name_var]}, _, []}) do
        [schema: schema, uuid_name_var: uuid_name_var]
        |> normalize_opts(unquote(name), unquote(version))
        |> __uuid__()
      end
    end

    defmacro unquote(name)(opts) when is_list(opts) do
      opts
      |> normalize_opts(unquote(name), unquote(version))
      |> __uuid__()
    end

    defmacro unquote(name)(schema) do
      __uuid__(schema: schema, uuid_version: unquote(version))
    end

    if version in [3, 5] do
      defmacro unquote(name)({{:., _, [schema, uuid_name_var]}, _, []}, opts) do
        opts
        |> Keyword.put(:schema, schema)
        |> Keyword.put(:uuid_name_var, uuid_name_var)
        |> normalize_opts(unquote(name), unquote(version))
        |> __uuid__()
      end
    end

    defmacro unquote(name)(schema, opts) do
      opts
      |> Keyword.put(:schema, schema)
      |> normalize_opts(unquote(name), unquote(version))
      |> __uuid__()
    end
  end)

  defp normalize_opts(opts, name, version) do
    if Keyword.has_key?(opts, :uuid_version) do
      raise ArgumentError, "trying to set :uuid_version on #{name}"
    end

    Keyword.put(opts, :uuid_version, version)
  end

  defp default_template(_opts), do: "{uuid}"

  @impl true
  def init(id_schema, opts) do
    opts =
      opts
      |> rename_keyword(:version, :uuid_version)
      |> rename_keyword(:format, :uuid_format)

    version = init_version(Id.Schema.option(opts, :uuid_version, id_schema))
    format = init_format(Id.Schema.option(opts, :uuid_format, id_schema), id_schema.namespace)

    opts =
      cond do
        version in [1, 4] ->
          opts

        version in [3, 5] ->
          opts
          |> rename_keyword(:namespace, :uuid_namespace)
          |> rename_keyword(:name_var, :uuid_name_var)

        true ->
          raise ArgumentError, "invalid UUID version: #{inspect(version)}"
      end

    install(
      id_schema,
      %__MODULE__{version: version, format: format}
      |> init_name_params(id_schema, opts)
    )
  end

  defp init_version(version) when version in [1, 3, 4, 5], do: version

  defp init_version(nil),
    do: raise(ArgumentError, "required :uuid_version keyword argument missing")

  defp init_version(invalid),
    do: raise(ArgumentError, "invalid :uuid_version: #{inspect(invalid)}")

  defp init_format(nil, %UrnNamespace{nid: :uuid}), do: :urn
  defp init_format(nil, _), do: :default
  defp init_format(format, %UrnNamespace{}) when format in ~w[default hex urn]a, do: format
  defp init_format(format, _) when format in ~w[default hex]a, do: format

  defp init_format(invalid, _),
    do: raise(ArgumentError, "invalid :uuid_format: #{inspect(invalid)}")

  defp init_name_params(%__MODULE__{version: version} = uuid_schema, id_schema, opts)
       when version in [3, 5] do
    %{
      uuid_schema
      | namespace: Id.Schema.option(opts, :uuid_namespace, id_schema),
        name_var: Id.Schema.option(opts, :uuid_name_var, id_schema)
    }
  end

  defp init_name_params(%{version: version} = uuid_schema, _id_schema, opts) do
    if Keyword.has_key?(opts, :uuid_namespace) do
      raise(ArgumentError, "uuid version #{version} doesn't support name arguments")
    else
      uuid_schema
    end
  end

  @impl true
  def call(%{version: 1, format: format}, _, variables, _),
    do: set_uuid(variables, UUID.uuid1(format), format)

  def call(%{version: 4, format: format}, _, variables, _),
    do: set_uuid(variables, UUID.uuid4(format), format)

  def call(
        %{version: 3, format: format, namespace: namespace, name_var: variable},
        _,
        variables,
        _
      ) do
    with {:ok, name} <- get_name(variables, variable) do
      set_uuid(variables, UUID.uuid3(namespace, name, format), format)
    end
  end

  def call(
        %{version: 5, format: format, namespace: namespace, name_var: variable},
        _,
        variables,
        _
      ) do
    with {:ok, name} <- get_name(variables, variable) do
      set_uuid(variables, UUID.uuid5(namespace, name, format), format)
    end
  end

  defp get_name(variables, variable) do
    case variables[variable] do
      nil -> {:error, "no value for field #{inspect(variable)} for UUID name present"}
      name -> {:ok, to_string(name)}
    end
  end

  defp set_uuid(variables, "urn:uuid:" <> uuid, :urn), do: set_uuid(variables, uuid, nil)
  defp set_uuid(variables, uuid, _), do: {:ok, Map.put(variables, :uuid, uuid)}
end
