defmodule RDF.Mapping.Schema do
  alias RDF.Mapping.Schema.Type
  alias RDF.Mapping.Link
  alias RDF.{Literal, IRI}

  import RDF.Utils

  @doc """
  Defines a mapping schema.
  """
  defmacro schema(class \\ nil, do: block) do
    schema(__CALLER__, class, block)
  end

  defp schema(caller, class, block) do
    prelude =
      quote do
        if line = Module.get_attribute(__MODULE__, :rdf_mapping_schema_defined) do
          raise "schema already defined for #{inspect(__MODULE__)} on line #{line}"
        end

        @rdf_mapping_schema_defined unquote(caller.line)

        @rdf_mapping_schema_class if unquote(class), do: IRI.to_string(unquote(class))
        def __class__(), do: @rdf_mapping_schema_class

        Module.register_attribute(__MODULE__, :rdf_property_mapping, accumulate: true)
        Module.register_attribute(__MODULE__, :rdf_property_opts, accumulate: true)
        Module.register_attribute(__MODULE__, :rdf_link_opts, accumulate: true)
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
        defstruct [:__id__ | @struct_fields]

        @property_map RDF.Mapping.Schema.property_mapping(@rdf_property_mapping)
        def __property_map__, do: @property_map
        def __property_map__(property), do: @property_map[property]

        @property_specs Map.new(@rdf_property_opts)
        def __property_spec__, do: @property_specs
        def __property_spec__(property), do: @property_specs[property]

        @link_specs Map.new(@rdf_link_opts)
        def __link_spec__(), do: @link_specs
        def __link_spec__(link), do: @link_specs[link]
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

  defmacro link(name, iri, opts) do
    iri = property_mapping_destination(iri)

    unless Keyword.has_key?(opts, :type),
      do: raise(ArgumentError, "type missing for link #{name}")

    opts =
      opts
      |> Keyword.update!(:type, &expand_alias(&1, __CALLER__))
      |> Keyword.put(:preload, Link.Preloader.normalize_spec(Keyword.get(opts, :preload), true))

    quote do
      RDF.Mapping.Schema.__link__(__MODULE__, unquote(name), unquote(iri), unquote(opts))
    end
  end

  @doc false
  def __property__(mod, name, iri, opts) do
    define_property(mod, name, iri, opts)
  end

  @doc false
  def __link__(mod, name, iri, opts) do
    define_link(mod, name, iri, opts)
  end

  defp define_property(mod, name, iri, opts) do
    opts = normalize_property_opts(mod, name, opts)

    virtual? = opts[:virtual] || is_nil(iri) || false

    Module.put_attribute(
      mod,
      :struct_fields,
      {name, Map.get(opts, :default, if(Type.set?(Map.get(opts, :type)), do: []))}
    )

    unless virtual? do
      Module.put_attribute(mod, :rdf_property_mapping, {name, iri})
      Module.put_attribute(mod, :rdf_property_opts, {name, opts})
    end
  end

  defp define_link(mod, name, iri, opts) do
    opts = normalize_link_opts(mod, name, opts)

    not_loaded = %Link.NotLoaded{
      __owner__: mod,
      __field__: name
    }

    Module.put_attribute(mod, :struct_fields, {name, not_loaded})
    Module.put_attribute(mod, :rdf_property_mapping, {name, iri})
    Module.put_attribute(mod, :rdf_link_opts, {name, opts})
  end

  defp normalize_link_opts(_mod, name, opts) do
    if Keyword.has_key?(opts, :default) do
      raise ArgumentError, "the :default option is not supported on links"
    end

    opts
    |> Map.new()
    |> lazy_map_update(:type, &normalize_link_type(name, &1, opts))
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

  defp normalize_link_type(name, nil, _opts) do
    raise ArgumentError, "type missing for property #{name}"
  end

  defp normalize_link_type(name, type, _opts) do
    case resource_type(type) do
      {:ok, type} ->
        type

      {:error, error} ->
        raise ArgumentError,
              "invalid type definition #{inspect(type)} for link #{name}: #{error}"
    end
  end

  defp resource_type([type]) do
    with {:ok, inner_type} <- resource_type(type) do
      {:ok, {:set, inner_type}}
    end
  end

  defp resource_type(type) do
    {:ok, {:resource, type}}
  end

  defp property_mapping_destination({:-, _line, [iri_expr]}), do: {:inverse, iri_expr}
  defp property_mapping_destination(iri_expr), do: iri_expr

  @doc false
  def property_mapping(property_mapping) do
    Map.new(property_mapping, fn
      {name, {:inverse, iri}} when is_atom(name) -> {name, {:inverse, RDF.iri(iri)}}
      {name, iri} when is_atom(name) -> {name, RDF.iri(iri)}
      bad -> raise ArgumentError, "bad property mapping: #{inspect(bad)}"
    end)
  end

  defp expand_alias({:__aliases__, _, _} = ast, env),
    do: Macro.expand(ast, %{env | function: {:__schema__, 2}})

  defp expand_alias(ast, _env),
    do: ast
end
