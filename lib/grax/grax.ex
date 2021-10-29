defmodule Grax do
  @moduledoc """
  The Grax API.

  For now there is no API documentation.
  Read about the API in the guide [here](https://rdf-elixir.dev/grax/api.html).
  """

  alias Grax.{Schema, Id, Validator, ValidationError}
  alias Grax.Schema.{DataProperty, LinkProperty}
  alias Grax.RDF.{Loader, Preloader, Mapper}

  alias RDF.{IRI, BlankNode, Graph, Statement}

  import RDF.Utils
  import RDF.Utils.Guards

  @__id__property_access_error Schema.InvalidProperty.exception(
                                 property: :__id__,
                                 message:
                                   "__id__ can't be changed. Use build/2 to construct a new Grax.Schema mapping from another with a new id."
                               )

  def build(mod, %IRI{} = id), do: {:ok, do_build(mod, id)}
  def build(mod, %BlankNode{} = id), do: {:ok, do_build(mod, id)}
  def build(mod, %Id.Schema{} = id_schema), do: build(mod, id_schema, %{})

  def build(mod, initial) when is_list(initial), do: build(mod, Map.new(initial))

  def build(mod, initial) when is_map(initial) do
    with {:ok, id} <- id(mod, initial) do
      build(mod, id, Map.delete(initial, :__id__))
    end
  end

  def build(mod, id) do
    if iri = IRI.new(id) do
      {:ok, do_build(mod, iri)}
    else
      raise ArgumentError, "invalid id: #{inspect(id)}"
    end
  end

  def build(mod, %Id.Schema{} = id_schema, initial) do
    with {:ok, id} <- id(id_schema, initial) do
      build(mod, id, initial)
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

  # TODO: use RDF.resource() in the following clause to get rid if this clause
  def id(_, %{__id__: %RDF.BlankNode{} = bnode}), do: {:ok, bnode}
  def id(_, %{__id__: id}), do: {:ok, RDF.iri(id)}

  def id(%Id.Schema{} = id_schema, attributes) do
    # TODO: Do we need/want to create an intermediary form without an id as the basis on which we apply the template in Id.Schema.generate_id?
    Id.Schema.generate_id(id_schema, attributes)
  end

  def id(schema, attributes) when maybe_module(schema) do
    schema
    |> id_schema(attributes)
    |> id(attributes)
  end

  def id(_, _), do: {:error, "no id schema found"}

  def id_schema(schema, initial) when is_atom(schema) do
    schema.__id_schema__() ||
      (schema.__id_spec__() &&
         Id.Spec.custom_select_id_schema(schema.__id_spec__(), schema, initial))
  end

  def load(mod, id, graph, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)
    opts = Keyword.put(opts, :validate, validate?)

    do_load(mod, id, graph, validate?, opts)
  end

  def load!(mod, id, graph, opts \\ []) do
    validate? = Keyword.get(opts, :validate, false)
    opts = Keyword.put_new(opts, :validate, validate?)

    with {:ok, mapping} <- do_load(mod, id, graph, validate?, opts) do
      mapping
    else
      {:error, error} -> raise error
    end
  end

  defp do_load(mod, id, graph, false, opts) do
    with {:ok, initial} <- build(mod, id),
         {:ok, loaded} <- Loader.call(mod, initial, graph, opts) do
      mod.on_load(loaded, graph, opts)
    end
  end

  defp do_load(mod, id, graph, true, opts) do
    with {:ok, mapping} <- do_load(mod, id, graph, false, opts) do
      validate(mapping, opts)
    end
  end

  def preload(%schema{} = mapping, graph, opts \\ []) do
    Preloader.call(schema, mapping, graph, setup_depth_preload_opts(opts))
  end

  def preload!(%schema{} = mapping, graph, opts \\ []) do
    Preloader.call(schema, mapping, graph, [
      {:validate, false} | setup_depth_preload_opts(opts)
    ])
    |> case do
      {:ok, mapping} -> mapping
      {:error, error} -> raise error
    end
  end

  def preloaded?(%schema{} = mapping) do
    schema.__properties__(:link)
    |> Enum.all?(fn {property, _} -> preloaded?(mapping, property) end)
  end

  def preloaded?(%schema{} = mapping, property) do
    case schema.__property__(property) do
      %LinkProperty{} -> mapping |> Map.get(property) |> do_preloaded?()
      %DataProperty{} -> true
      _ -> raise ArgumentError, "#{inspect(property)} is not a property of #{schema}"
    end
  end

  defp do_preloaded?(nil), do: nil
  defp do_preloaded?(%IRI{}), do: false
  defp do_preloaded?(%BlankNode{}), do: false
  defp do_preloaded?([]), do: true
  defp do_preloaded?([value | _]), do: do_preloaded?(value)
  defp do_preloaded?(%_{}), do: true
  # This is the fallback case with an apparently invalid value.
  defp do_preloaded?(_), do: false

  # TODO: This is a wrapper acting as a preliminary substitute for the preloading strategy selector
  def setup_depth_preload_opts(opts) do
    case Keyword.pop(opts, :depth) do
      {nil, _} -> opts
      {depth, opts} -> Keyword.put_new(opts, :preload, normalize_preload_opt(depth))
    end
  end

  @doc false
  def normalize_preload_opt(preload_value)
  def normalize_preload_opt(nil), do: nil
  def normalize_preload_opt(integer) when is_integer(integer), do: {:add_depth, integer}

  def normalize_preload_opt({keyword, _} = depth, _) when keyword in [:depth, :add_depth],
    do: depth

  def normalize_preload_opt(invalid, _),
    do: raise(ArgumentError, "invalid depth specification: #{inspect(invalid)}")

  @doc false
  def normalize_preload_spec(preload_value)
  def normalize_preload_spec(integer) when is_integer(integer), do: {:depth, integer}

  def normalize_preload_spec({:+, _line, [integer]}) when is_integer(integer),
    do: {:add_depth, integer}

  def normalize_preload_spec(preload_value), do: normalize_preload_opt(preload_value)

  def put(_, :__id__, _), do: {:error, @__id__property_access_error}

  # Note, this clause is duplicated on put!/3
  def put(mapping, :__additional_statements__, predications) do
    {:ok, put_additional_statements(mapping, predications)}
  end

  def put(%schema{} = mapping, property, value) do
    if Schema.has_field?(schema, property) do
      cond do
        property_schema = schema.__property__(property) ->
          validation =
            case property_schema.__struct__ do
              DataProperty -> :check_property
              LinkProperty -> :check_link
            end

          do_put_property(validation, mapping, property, value, property_schema)

        # it's a simple, unmapped field
        true ->
          {:ok, struct!(mapping, [{property, value}])}
      end
    else
      {:error, Schema.InvalidProperty.exception(property: property)}
    end
  end

  def put(%_{} = mapping, values) do
    Enum.reduce(values, {mapping, ValidationError.exception(context: mapping.__id__)}, fn
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
    with {:ok, value} <-
           value
           |> normalize_value(property_schema)
           |> build_linked(property_schema) do
      Validator
      |> apply(validation, [
        ValidationError.exception(context: mapping.__id__),
        property,
        value,
        property_schema,
        []
      ])
      |> case do
        %{errors: []} -> {:ok, struct!(mapping, [{property, value}])}
        %{errors: errors} -> {:error, errors[property]}
      end
    end
  end

  def put!(_, :__id__, _), do: raise(@__id__property_access_error)

  # Note, this clause is duplicated on put/3
  def put!(mapping, :__additional_statements__, predications) do
    put_additional_statements(mapping, predications)
  end

  def put!(%schema{} = mapping, property, value) do
    property_schema = schema.__property__(property)

    value
    |> normalize_value(property_schema)
    |> build_linked(property_schema)
    |> case do
      {:ok, value} -> struct!(mapping, [{property, value}])
      {:error, error} -> raise error
    end
  end

  def put!(%_{} = mapping, values) do
    Enum.reduce(values, mapping, fn
      {property, value}, mapping ->
        put!(mapping, property, value)
    end)
  end

  defp normalize_value(value, property_schema) do
    normalized_value =
      value
      |> uniq_value()
      |> normalize_list_value(Schema.Property.value_set?(property_schema))

    if property_schema do
      normalize_type(
        normalized_value,
        property_schema.__struct__,
        Schema.Property.value_type(property_schema)
      )
    else
      normalized_value
    end
  end

  defp uniq_value(value) when is_list(value), do: Enum.uniq(value)
  defp uniq_value(value), do: value

  defp normalize_list_value(value, true), do: List.wrap(value)
  defp normalize_list_value([value], false), do: value
  defp normalize_list_value(value, false), do: value

  defp normalize_type(values, DataProperty, IRI) when is_list(values),
    do: Enum.map(values, &normalize_type(&1, DataProperty, IRI))

  defp normalize_type(%IRI{} = iri, DataProperty, IRI), do: iri
  defp normalize_type(term, DataProperty, IRI) when maybe_module(term), do: IRI.new(term)
  defp normalize_type(value, _, _), do: value

  defp build_linked(values, %LinkProperty{} = property_schema) when is_list(values) do
    map_while_ok(values, &build_linked(&1, property_schema))
  end

  defp build_linked(%IRI{} = value, %LinkProperty{}), do: {:ok, value}
  defp build_linked(%BlankNode{} = value, %LinkProperty{}), do: {:ok, value}
  defp build_linked(term, %LinkProperty{}) when maybe_module(term), do: {:ok, IRI.new(term)}

  defp build_linked(%{} = value, %LinkProperty{} = property_schema) do
    if Map.has_key?(value, :__struct__) do
      {:ok, value}
    else
      case LinkProperty.value_type(property_schema) do
        nil ->
          raise ArgumentError,
                "unable to determine value type of property #{inspect(property_schema)}"

        %{} = class_mapping when not is_struct(class_mapping) ->
          raise ArgumentError,
                "unable to determine value type of heterogeneous property #{inspect(property_schema)}"

        resource_type ->
          resource_type.build(value)
      end
    end
  end

  defp build_linked(value, _), do: {:ok, value}

  @spec add_additional_statements(Schema.t(), keyword()) :: Schema.t()
  def add_additional_statements(%_{} = mapping, predications) do
    %{
      mapping
      | __additional_statements__:
          do_add_additional_statements(mapping.__additional_statements__, predications)
    }
  end

  defp do_add_additional_statements(additional_statements, predications) do
    Enum.reduce(predications, additional_statements, fn
      {predicate, objects}, additional_statements ->
        coerced_objects =
          objects
          |> List.wrap()
          |> Enum.map(&Statement.coerce_object/1)
          |> MapSet.new()

        Map.update(
          additional_statements,
          Statement.coerce_predicate(predicate),
          coerced_objects,
          &MapSet.union(&1, coerced_objects)
        )
    end)
  end

  @spec put_additional_statements(Schema.t(), keyword()) :: Schema.t()
  def put_additional_statements(%_{} = mapping, predications) do
    %{
      mapping
      | __additional_statements__:
          do_put_additional_statements(mapping.__additional_statements__, predications)
    }
  end

  defp do_put_additional_statements(additional_statements, predications) do
    Enum.reduce(predications, additional_statements, fn
      {predicate, nil}, additional_statements ->
        Map.delete(additional_statements, Statement.coerce_predicate(predicate))

      {predicate, objects}, additional_statements ->
        Map.put(
          additional_statements,
          Statement.coerce_predicate(predicate),
          objects
          |> List.wrap()
          |> Enum.map(&Statement.coerce_object/1)
          |> MapSet.new()
        )
    end)
  end

  @spec validate(Schema.t(), opts :: keyword()) ::
          {:ok, Schema.t()} | {:error, ValidationError.t()}
  def validate(%_{} = mapping, opts \\ []) do
    Validator.call(mapping, opts)
  end

  @spec validate!(Schema.t(), opts :: keyword()) :: Schema.t()
  def validate!(%_{} = mapping, opts \\ []) do
    case validate(mapping, opts) do
      {:ok, _} -> mapping
      {:error, error} -> raise error
    end
  end

  @spec valid?(Schema.t(), opts :: keyword()) :: boolean
  def valid?(%_{} = mapping, opts \\ []) do
    match?({:ok, _}, validate(mapping, opts))
  end

  @spec to_rdf(Schema.t(), opts :: keyword()) :: {:ok, Graph.t()} | {:error, any}
  def to_rdf(%schema{} = mapping, opts \\ []) do
    with {:ok, rdf} <- Mapper.call(mapping, opts) do
      schema.on_to_rdf(mapping, rdf, opts)
    end
  end
end
