defmodule RDF.Mapping do
  alias RDF.Mapping.{Schema, Link, Loader, Validation, ToRDF, ValidationError}
  alias RDF.{IRI, BlankNode, Graph, Description}

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
      def build(%IRI{} = id), do: do_build(id)
      def build(%BlankNode{} = id), do: do_build(id)

      def build(id) do
        if iri = IRI.new(id) do
          do_build(iri)
        else
          raise ArgumentError, "invalid id: #{inspect(id)}"
        end
      end

      def build!(id) do
        case build(id) do
          {:ok, mapping} -> mapping
          {:error, error} -> raise error
        end
      end

      defp do_build(id) do
        {:ok, %__MODULE__{__id__: id}}
      end

      @spec load(Graph.t() | Description.t(), IRI.coercible() | BlankNode.t(), opts :: Keyword) ::
              {:ok, struct} | {:error, any}
      def load(graph, id, opts \\ []) do
        with {:ok, initial} <- build(id) do
          Loader.call(__MODULE__, initial, graph, opts)
        end
      end

      @doc false
      def __has_property__?(property) do
        Keyword.has_key?(@struct_fields, property)
      end

      @spec to_rdf(struct, opts :: Keyword) :: {:ok, Graph.t()} | {:error, any}
      def to_rdf(%__MODULE__{} = mapping, opts \\ []) do
        ToRDF.call(mapping, opts)
      end
    end
  end

  @__id__property_access_error Schema.InvalidProperty.exception(
                                 property: :__id__,
                                 message:
                                   "Please use the change_id/2 function to update :__id__ attribute"
                               )
  def put(_, :__id__, _), do: {:error, @__id__property_access_error}

  def put(%mapping_mod{} = mapping, property, value) do
    if mapping_mod.__has_property__?(property) do
      cond do
        property_spec = mapping_mod.__property_spec__(property) ->
          do_put_property(:check_property, mapping, property, value, property_spec)

        link_spec = mapping_mod.__link_spec__(property) ->
          do_put_property(:check_link, mapping, property, value, link_spec)

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

  defp do_put_property(validation, mapping, property, value, property_spec) do
    value = if Schema.Type.set?(property_spec.type), do: List.wrap(value), else: value

    Validation
    |> apply(validation, [ValidationError.exception(), property, value, property_spec, []])
    |> case do
      %{errors: []} -> {:ok, struct!(mapping, [{property, value}])}
      %{errors: errors} -> {:error, errors[property]}
    end
  end

  def put!(_, :__id__, _), do: raise(@__id__property_access_error)

  def put!(%mapping_mod{} = mapping, property, value) do
    property_spec =
      mapping_mod.__property_spec__(property) ||
        mapping_mod.__link_spec__(property)

    value =
      if property_spec && Schema.Type.set?(property_spec.type), do: List.wrap(value), else: value

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
end
