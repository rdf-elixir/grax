defmodule RDF.Mapping do
  alias RDF.Mapping.{Schema, Link, Loader, Validation, ToRDF, ValidationError}
  alias RDF.{IRI, BlankNode, Graph, Description}

  @__id__property_access_error Schema.InvalidProperty.exception(
                                 property: :__id__,
                                 message:
                                   "__id__ can't be changed. Use build/2 to construct a mapping from another with new id."
                               )

  defmacro __using__(opts) do
    preload_default = Link.Preloader.normalize_spec(Keyword.get(opts, :preload), true)

    quote do
      import Schema, only: [schema: 1, schema: 2]

      @before_compile unquote(__MODULE__)

      @rdf_mapping_preload_default unquote(preload_default)
      def __preload_default__(), do: @rdf_mapping_preload_default
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def build(id), do: RDF.Mapping.build(__MODULE__, id)
      def build(id, initial), do: RDF.Mapping.build(__MODULE__, id, initial)
      def build!(id), do: RDF.Mapping.build!(__MODULE__, id)
      def build!(id, initial), do: RDF.Mapping.build!(__MODULE__, id, initial)

      @spec load(Graph.t() | Description.t(), IRI.coercible() | BlankNode.t(), opts :: Keyword) ::
              {:ok, struct} | {:error, any}
      def load(graph, id, opts \\ []) do
        with {:ok, initial} <- build(id) do
          Loader.call(__MODULE__, initial, graph, opts)
        end
      end

      @doc false
      def __has_property__?(property), do: Keyword.has_key?(@struct_fields, property)

      Module.delete_attribute(__MODULE__, :rdf_property_acc)
    end
  end

  def build(mod, %IRI{} = id), do: {:ok, do_build(mod, id)}
  def build(mod, %BlankNode{} = id), do: {:ok, do_build(mod, id)}

  def build(mod, id) do
    if iri = IRI.new(id) do
      {:ok, do_build(mod, iri)}
    else
      raise ArgumentError, "invalid id: #{inspect(id)}"
    end
  end

  def build(mod, id, %mod{} = initial) do
    mod
    |> build!(id, initial)
    |> validate()
  end

  def build(mod, id, initial) do
    with {:ok, mapping} <- build(mod, id) do
      put(mapping, initial)
    end
  end

  def build!(mod, id) do
    case build(mod, id) do
      {:ok, mapping} -> mapping
      {:error, error} -> raise error
    end
  end

  def build!(mod, id, %mod{} = initial) do
    struct(initial, __id__: build!(mod, id).__id__)
  end

  def build!(mod, id, initial) do
    mod
    |> build!(id)
    |> put!(initial)
  end

  defp do_build(mod, id) do
    struct(mod, __id__: id)
  end

  def put(_, :__id__, _), do: {:error, @__id__property_access_error}

  def put(%mapping_mod{} = mapping, property, value) do
    if mapping_mod.__has_property__?(property) do
      cond do
        property_schema = mapping_mod.__property__(property) ->
          validation =
            case property_schema.__struct__ do
              Schema.DataProperty -> :check_property
              Schema.LinkProperty -> :check_link
            end

          do_put_property(validation, mapping, property, value, property_schema)

        # it's a virtual property
        true ->
          {:ok, struct!(mapping, [{property, value}])}
      end
    else
      {:error, Schema.InvalidProperty.exception(property: property)}
    end
  end

  def put(%_{} = mapping, values) do
    Enum.reduce(values, {mapping, ValidationError.exception()}, fn
      {property, value}, {mapping, validation} ->
        mapping
        |> put(property, value)
        |> case do
          {:ok, mapping} -> {mapping, validation}
          {:error, error} -> {mapping, ValidationError.add_error(validation, property, error)}
        end
    end)
    |> case do
      {mapping, %ValidationError{errors: []}} -> {:ok, mapping}
      {_, validation} -> {:error, validation}
    end
  end

  defp do_put_property(validation, mapping, property, value, property_schema) do
    value = if Schema.Type.set?(property_schema.type), do: List.wrap(value), else: value

    Validation
    |> apply(validation, [ValidationError.exception(), property, value, property_schema, []])
    |> case do
      %{errors: []} -> {:ok, struct!(mapping, [{property, value}])}
      %{errors: errors} -> {:error, errors[property]}
    end
  end

  def put!(_, :__id__, _), do: raise(@__id__property_access_error)

  def put!(%mapping_mod{} = mapping, property, value) do
    property_schema = mapping_mod.__property__(property)

    value =
      if property_schema && Schema.Type.set?(property_schema.type),
        do: List.wrap(value),
        else: value

    struct!(mapping, [{property, value}])
  end

  def put!(%_{} = mapping, values) do
    Enum.reduce(values, mapping, fn
      {property, value}, mapping ->
        put!(mapping, property, value)
    end)
  end

  @spec validate(struct, opts :: Keyword) :: {:ok, struct} | {:error, ValidationError.t()}
  def validate(%_{} = mapping, opts \\ []) do
    Validation.call(mapping, opts)
  end

  @spec validate!(struct, opts :: Keyword) :: struct
  def validate!(%_{} = mapping, opts \\ []) do
    case validate(mapping, opts) do
      {:ok, _} -> mapping
      {:error, error} -> raise error
    end
  end

  @spec valid?(struct, opts :: Keyword) :: boolean
  def valid?(%_{} = mapping, opts \\ []) do
    match?({:ok, _}, validate(mapping, opts))
  end

  @spec to_rdf(struct, opts :: Keyword) :: {:ok, Graph.t()} | {:error, any}
  def to_rdf(%_{} = mapping, opts \\ []) do
    ToRDF.call(mapping, opts)
  end
end
