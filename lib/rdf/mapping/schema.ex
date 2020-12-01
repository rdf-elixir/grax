defmodule RDF.Mapping.Schema do
  alias RDF.Mapping.Schema.Type
  alias RDF.Mapping.Association
  alias RDF.{Literal, PropertyMap}

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
    define_property(mod, name, iri, opts)
  end

  @doc false
  def __has_one__(mod, name, iri, opts) do
    define_association(mod, name, iri, :one, opts)
  end

  @doc false
  def __has_many__(mod, name, iri, opts) do
    define_association(mod, name, iri, :many, opts)
  end

  defp define_property(mod, name, iri, opts) do
    opts = normalize_property_opts(mod, name, opts)

    virtual? = opts[:virtual] || is_nil(iri) || false
    Module.put_attribute(mod, :struct_fields, {name, Map.get(opts, :default)})

    unless virtual? do
      Module.put_attribute(mod, :rdf_property_mapping, {name, iri})
      Module.put_attribute(mod, :rdf_property_opts, {name, opts})
    end
  end

  defp define_association(mod, name, iri, cardinality, opts) do
    opts = normalize_association_opts(mod, name, cardinality, opts)

    not_loaded = %Association.NotLoaded{
      __owner__: mod,
      __field__: name,
      __cardinality__: cardinality
    }

    Module.put_attribute(mod, :struct_fields, {name, not_loaded})
    Module.put_attribute(mod, :rdf_property_mapping, {name, iri})
    Module.put_attribute(mod, :rdf_property_opts, {name, opts})
  end

  defp normalize_association_opts(_mod, name, cardinality, opts) do
    if Keyword.has_key?(opts, :default) do
      raise ArgumentError, "the :default option is not supported on associations"
    end

    opts
    |> Map.new()
    |> lazy_map_update(:type, &normalize_association_type(name, &1, cardinality, opts))
  end

  defp normalize_property_opts(_mod, name, opts) do
    opts
    |> Map.new()
    |> lazy_map_update(:type, &normalize_property_type(name, &1, opts))
    |> check_default_value()
  end

  defp check_default_value(%{default: _, type: {:set, _}}) do
    raise ArgumentError, "the :default option is not supported on sets"
  end

  defp check_default_value(%{type: nil} = opts), do: opts

  defp check_default_value(%{default: default, type: type} = opts) do
    if Literal.new(default) |> Literal.is_a?(type) do
      opts
    else
      raise ArgumentError, "default value #{inspect(default)} doesn't match type #{type}"
    end
  end

  defp check_default_value(opts), do: opts

  @default_property_type :any

  defp normalize_property_type(name, nil, opts) do
    normalize_property_type(name, @default_property_type, opts)
  end

  defp normalize_property_type(name, type, _opts) do
    case Type.get(type) do
      {:ok, type} ->
        type

      {:error, error} ->
        raise ArgumentError,
              "invalid type definition #{inspect(type)} for property #{name}: #{error}"
    end
  end

  defp normalize_association_type(name, nil, _cardinality, _opts) do
    raise ArgumentError, "type missing for property #{name}"
  end

  defp normalize_association_type(name, type, cardinality, _opts) do
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
