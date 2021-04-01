if Code.ensure_loaded?(UUID) do
  defmodule Grax.Id.UUID do
    use Grax.Id.Schema.Extension

    defstruct [:version, :format, :namespace, :name]

    defmacro uuid(opts) do
      template = Keyword.get(opts, :template, default_template(opts))
      opts = extension_opt(__MODULE__, opts)

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

      defmacro unquote(name)(schema, opts) do
        opts = normalize_opts(opts, unquote(name), unquote(version))

        quote do
          uuid unquote(schema), unquote(opts)
        end
      end
    end)

    defp normalize_opts(opts, name, version) do
      if Keyword.has_key?(opts, :uuid_version) do
        raise ArgumentError, "trying to set :uuid_version on #{name}"
      end

      if version in [3, 5] do
        opts
        |> rename_keyword(:namespace, :uuid_namespace)
        |> rename_keyword(:name, :uuid_name)
      else
        opts
      end
      |> rename_keyword(:format, :uuid_format)
      |> Keyword.put(:uuid_version, version)
    end

    defp rename_keyword(opts, old_name, new_name) do
      if Keyword.has_key?(opts, old_name) do
        opts
        |> Keyword.put(new_name, Keyword.get(opts, old_name))
        |> Keyword.delete_first(old_name)
      else
        opts
      end
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

    def call(%{version: 3, format: format, namespace: namespace, name: name}, _, variables, _),
      do: set_uuid(variables, UUID.uuid3(namespace, get_name(variables, name), format))

    def call(%{version: 5, format: format, namespace: namespace, name: name}, _, variables, _),
      do: set_uuid(variables, UUID.uuid5(namespace, get_name(variables, name), format))

    defp get_name(variables, name) do
      variables[name] || raise "name #{name} for UUID generation not present"
    end

    defp set_uuid(variables, uuid) when is_map(variables),
      do: {:ok, Map.put(variables, :uuid, uuid)}

    defp set_uuid(variables, uuid),
      do: {:ok, Keyword.put(variables, :uuid, uuid)}
  end
end
