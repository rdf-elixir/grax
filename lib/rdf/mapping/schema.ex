defmodule RDF.Mapping.Schema do
  alias RDF.Mapping.Schema.Type
  alias RDF.PropertyMap

  import RDF.Utils

  @doc """
  Defines a mapping schema.
  """
  defmacro schema(do: block) do
    schema(__CALLER__, block)
  end

  defp schema(caller, block) do
    prelude =
      quote do
        if line = Module.get_attribute(__MODULE__, :rdf_mapping_schema_defined) do
          raise "schema already defined for #{inspect(__MODULE__)} on line #{line}"
        end

        @rdf_mapping_schema_defined unquote(caller.line)

        Module.register_attribute(__MODULE__, :rdf_property_mapping, accumulate: true)
        Module.register_attribute(__MODULE__, :rdf_property_opts, accumulate: true)
        Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)

        try do
          import unquote(__MODULE__)
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do
        unless Module.defines?(__MODULE__, {:__struct__, 0}, :def) do
          defstruct [:__iri__ | @struct_fields]
        end

        @property_map PropertyMap.new(@rdf_property_mapping)
        def __property_map__, do: @property_map

        @property_specs Map.new(@rdf_property_opts)
        def __property_spec__(property), do: @property_specs[property]
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro property(name, iri, opts \\ []) do
    quote do
      RDF.Mapping.Schema.__property__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  defmacro has_one(name, iri, opts) do
    unless Keyword.has_key?(opts, :type),
      do: raise(ArgumentError, "type missing for property #{name}")

    opts = Keyword.update!(opts, :type, &expand_alias(&1, __CALLER__))

    quote do
      RDF.Mapping.Schema.__has_one__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  defmacro has_many(name, iri, opts) do
    unless Keyword.has_key?(opts, :type),
      do: raise(ArgumentError, "type missing for property #{name}")

    opts = Keyword.update!(opts, :type, &expand_alias(&1, __CALLER__))

    quote do
      RDF.Mapping.Schema.__has_many__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  @doc false
  def __property__(mod, name, iri, opts) do
    define_property(mod, name, iri, normalize_property_opts(:literal, mod, name, opts))
  end

  @doc false
  def __has_one__(mod, name, iri, opts) do
    define_property(mod, name, iri, normalize_property_opts({:resource, :one}, mod, name, opts))
  end

  @doc false
  def __has_many__(mod, name, iri, opts) do
    define_property(mod, name, iri, normalize_property_opts({:resource, :many}, mod, name, opts))
  end

  defp define_property(mod, name, iri, opts) do
    virtual? = opts[:virtual] || is_nil(iri) || false
    Module.put_attribute(mod, :struct_fields, {name, Map.get(opts, :default)})

    unless virtual? do
      Module.put_attribute(mod, :rdf_property_mapping, {name, iri})
      Module.put_attribute(mod, :rdf_property_opts, {name, opts})
    end
  end

  defp normalize_property_opts(kind, _mod, name, opts) do
    opts
    |> Map.new()
    |> lazy_map_update(:type, &normalize_property_type(kind, name, &1, opts))
  end

  @default_property_type :any

  defp normalize_property_type(:literal, name, nil, opts) do
    normalize_property_type(:literal, name, @default_property_type, opts)
  end

  defp normalize_property_type(_, name, nil, _opts) do
    raise ArgumentError, "type missing for property #{name}"
  end

  defp normalize_property_type(:literal, name, type, _opts) do
    case Type.get(type) do
      {:ok, type} ->
        type

      {:error, error} ->
        raise ArgumentError,
              "invalid type definition #{inspect(type)} for property #{name}: #{error}"
    end
  end

  defp normalize_property_type({:resource, cardinality}, name, type, _opts) do
    case resource_type(type, cardinality) do
      {:ok, type} ->
        type

      {:error, error} ->
        raise ArgumentError,
              "invalid type definition #{inspect(type)} for association property #{name}: #{error}"
    end
  end

  defp resource_type(type, cardinality \\ :one)

  defp resource_type(type, :many) do
    with {:ok, inner_type} <- resource_type(type) do
      {:ok, {:set, inner_type}}
    end
  end

  defp resource_type(type, :one) do
    {:ok, {:resource, type}}
  end

  defp expand_alias({:__aliases__, _, _} = ast, env),
    do: Macro.expand(ast, %{env | function: {:__schema__, 2}})

  defp expand_alias(ast, _env),
    do: ast
end
