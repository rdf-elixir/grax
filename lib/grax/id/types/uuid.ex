if Code.ensure_loaded?(UUID) do
  defmodule Grax.Id.UUID do
    use Grax.Id.Schema.Extension

    import Grax.Utils, only: [rename_keyword: 3]

    defstruct [:version, :format, :namespace, :name]

    defmacro uuid(opts) do
      opts =
        __MODULE__
        |> extension_opt(opts)
        |> normalize_opts()

      template = Keyword.get(opts, :template, default_template(opts))

      quote do
        id_schema unquote(template), unquote(opts)
      end
    end

    defmacro uuid(schema, opts) do
      opts = Keyword.put(opts, :schema, schema)

      quote do
        uuid unquote(opts)
      end
    end

    Enum.each([1, 3, 4, 5], fn version ->
      name = String.to_atom("uuid#{version}")

      defmacro unquote(name)(opts) when is_list(opts) do
        opts = normalize_opts(opts, unquote(name), unquote(version))

        quote do
          uuid unquote(opts)
        end
      end

      defmacro unquote(name)(schema) do
        opts = [uuid_version: unquote(version)]

        quote do
          uuid unquote(schema), unquote(opts)
        end
      end

      if version in [3, 5] do
        defmacro unquote(name)({{:., _, [schema, uuid_name]}, _, []}, opts) do
          opts =
            opts
            |> normalize_opts(unquote(name), unquote(version))
            |> Keyword.put(:uuid_name, uuid_name)

          quote do
            uuid unquote(schema), unquote(opts)
          end
        end
      end

      defmacro unquote(name)(schema, opts) do
        opts = normalize_opts(opts, unquote(name), unquote(version))

        quote do
          uuid unquote(schema), unquote(opts)
        end
      end
    end)

    defp normalize_opts(opts) do
      opts =
        opts
        |> rename_keyword(:version, :uuid_version)
        |> rename_keyword(:format, :uuid_format)

      version = Keyword.get(opts, :uuid_version)

      cond do
        version in [1, 4] ->
          opts

        version in [3, 5] ->
          opts
          |> rename_keyword(:namespace, :uuid_namespace)
          |> rename_keyword(:name, :uuid_name)

        true ->
          raise ArgumentError, "invalid UUID version: #{inspect(version)}"
      end
    end

    defp normalize_opts(opts, name, version) do
      if Keyword.has_key?(opts, :uuid_version) do
        raise ArgumentError, "trying to set :uuid_version on #{name}"
      end

      Keyword.put(opts, :uuid_version, version)
    end

    defp default_template(_opts), do: "{uuid}"

    @impl true
    def init(id_schema, opts) do
      install(
        id_schema,
        %__MODULE__{
          version: init_version(Keyword.get(opts, :uuid_version)),
          format: init_format(Keyword.get(opts, :uuid_format))
        }
        |> init_name_params(opts)
      )
    end

    defp init_version(version) when version in [1, 3, 4, 5], do: version

    defp init_version(nil),
      do: raise(ArgumentError, "required :uuid_version keyword argument missing")

    defp init_version(invalid),
      do: raise(ArgumentError, "invalid :uuid_version: #{inspect(invalid)}")

    defp init_format(format) when format in ~w[default hex]a, do: format
    defp init_format(nil), do: :default

    defp init_format(invalid),
      do: raise(ArgumentError, "invalid :uuid_format: #{inspect(invalid)}")

    defp init_name_params(%{version: version} = uuid_schema, opts) when version in [3, 5] do
      %__MODULE__{
        uuid_schema
        | namespace: Keyword.fetch!(opts, :uuid_namespace),
          name: Keyword.fetch!(opts, :uuid_name)
      }
    end

    defp init_name_params(%{version: version} = uuid_schema, opts) do
      if Keyword.has_key?(opts, :uuid_namespace) or Keyword.has_key?(opts, :uuid_namespace) do
        raise(ArgumentError, "uuid version #{version} doesn't support name arguments")
      else
        uuid_schema
      end
    end

    @impl true
    def call(%{version: 1, format: format}, _, variables, _),
      do: set_uuid(variables, UUID.uuid1(format))

    def call(%{version: 4, format: format}, _, variables, _),
      do: set_uuid(variables, UUID.uuid4(format))

    def call(%{version: 3, format: format, namespace: namespace, name: variable}, _, variables, _) do
      with {:ok, name} <- get_name(variables, variable) do
        set_uuid(variables, UUID.uuid3(namespace, name, format))
      end
    end

    def call(%{version: 5, format: format, namespace: namespace, name: variable}, _, variables, _) do
      with {:ok, name} <- get_name(variables, variable) do
        set_uuid(variables, UUID.uuid5(namespace, name, format))
      end
    end

    defp get_name(variables, variable) do
      case variables[variable] do
        nil -> {:error, "no value for field #{inspect(variable)} for UUID name present"}
        name -> {:ok, to_string(name)}
      end
    end

    defp set_uuid(variables, uuid),
      do: {:ok, Map.put(variables, :uuid, uuid)}
  end
end
