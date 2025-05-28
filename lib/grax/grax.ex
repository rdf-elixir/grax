defmodule Grax do
  @moduledoc """
  The Grax API.

  For now there is no API documentation.
  Read about the API in the guide [here](https://rdf-elixir.dev/grax/api.html).
  """

  alias Grax.{Schema, Id, Validator, ValidationError}

  alias Grax.Schema.{
    Registry,
    DataProperty,
    LinkProperty,
    AdditionalStatements,
    Inheritance,
    DetectionError
  }

  alias Grax.RDF.{Loader, Preloader, Mapper, Access}

  alias RDF.{IRI, BlankNode, Graph, Description, Statement}

  import RDF.Guards
  import RDF.Utils
  import RDF.Utils.Guards

  @__id__property_access_error Schema.InvalidPropertyError.exception(
                                 property: :__id__,
                                 message:
                                   "__id__ can't be changed. Use build/2 to construct a new Grax.Schema mapping from another with a new id."
                               )

  def build(mod, id) when is_rdf_resource(id), do: {:ok, do_build(mod, id)}
  def build(mod, %Id.Schema{} = id_schema), do: build(mod, id_schema, %{})

  def build(mod, initial) when is_list(initial), do: build(mod, Map.new(initial))

  def build(mod, initial) when is_map(initial) do
    with {:ok, id} <- build_id(mod, initial) do
      build(mod, id, Map.delete(initial, :__id__))
    end
  end

  def build(mod, id) do
    {:ok, do_build(mod, IRI.new(id))}
  end

  def build(mod, %Id.Schema{} = id_schema, initial) do
    with {:ok, id} <- build_id(id_schema, initial) do
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

  def build_id(_, %{__id__: id}) when is_rdf_resource(id), do: {:ok, id}
  def build_id(_, %{__id__: id}) when not is_nil(id), do: {:ok, RDF.iri(id)}

  def build_id(%Id.Schema{} = id_schema, attributes) do
    Id.Schema.generate_id(id_schema, attributes)
  end

  def build_id(schema, attributes) when maybe_module(schema) do
    schema
    |> id_schema(attributes)
    |> build_id(attributes)
  end

  def build_id(_, _), do: {:error, "no id schema found"}

  def id_schema(schema, initial) when is_atom(schema) do
    schema.__id_schema__() ||
      (schema.__id_spec__() &&
         Id.Spec.custom_select_id_schema(schema.__id_spec__(), schema, initial))
  end

  @doc """
  Returns the id of a Grax struct.

  This should be the preferred over accessing the `:__id__` field directly.

  ## Example

      iex> user = Example.User.build!(EX.User, name: "John Doe")
      ...> Grax.id(user)
      ~I<http://example.com/User>

  """
  def id(%{__id__: id}), do: id

  @doc """
  Resets the id of the given Grax schema `struct` by reapplying its `Grax.Id.Schema`.
  """
  @spec reset_id(Schema.t()) :: Schema.t()
  def reset_id(%schema{} = struct) do
    case build_id(schema, %{struct | __id__: nil}) do
      {:ok, id} -> reset_id(struct, id)
      {:error, error} -> raise error
    end
  end

  @doc """
  Resets the id of the given Grax schema `struct` to the given `id`.

  This should always be preferred over setting the `__id__` field directly.
  """
  @spec reset_id(Schema.t(), RDF.Resource.coercible()) :: Schema.t()
  def reset_id(schema, id)

  def reset_id(%_{} = schema, id) when is_rdf_resource(id) do
    %{schema | __id__: id}
  end

  def reset_id(%_{} = schema, id), do: reset_id(schema, RDF.iri(id))

  def load(graph, id), do: load(graph, id, nil, [])
  def load(graph, id, opts) when is_list(opts), do: load(graph, id, nil, opts)
  def load(graph, id, mod), do: load(graph, id, mod, [])

  def load(graph, id, nil, opts) do
    description = Access.description(graph, id)

    case Inheritance.determine_schema(description) do
      no_unique when is_nil(no_unique) or is_list(no_unique) ->
        {:error, DetectionError.exception(candidates: no_unique, context: id)}

      schema ->
        load(graph, id, schema, Keyword.put(opts, :description, description))
    end
  end

  def load(graph, id, mod, opts) do
    validate? = Keyword.get(opts, :validate, true)
    opts = Keyword.put(opts, :validate, validate?)

    do_load(mod, id, graph, validate?, opts)
  end

  def load!(graph, id), do: load!(graph, id, nil, [])
  def load!(graph, id, opts) when is_list(opts), do: load!(graph, id, nil, opts)
  def load!(graph, id, mod), do: load!(graph, id, mod, [])

  def load!(graph, id, mod, opts) do
    case load(graph, id, mod, Keyword.put_new(opts, :validate, false)) do
      {:ok, mapping} -> mapping
      {:error, error} -> raise error
    end
  end

  defp do_load(mod, id, graph, false, opts) do
    with {:ok, initial} <- mod.build(id),
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
      if property_schema = schema.__property__(property) do
        validation =
          case property_schema.__struct__ do
            DataProperty -> :check_property
            LinkProperty -> :check_link
          end

        do_put_property(validation, mapping, property, value, property_schema)
      else
        # it's a simple, unmapped field
        {:ok, struct!(mapping, [{property, value}])}
      end
    else
      {:error, Schema.InvalidPropertyError.exception(property: property)}
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
      if property_schema do
        value
        |> uniq_value()
        |> normalize_list_value(Schema.Property.value_set?(property_schema))
      else
        value
      end

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

        %LinkProperty.Union{} ->
          raise ArgumentError,
                "unable to determine value type of union link property #{inspect(property_schema)}"

        resource_type ->
          resource_type.build(value)
      end
    end
  end

  defp build_linked(value, _), do: {:ok, value}

  @spec additional_statements(Schema.t()) :: RDF.Description.t()
  def additional_statements(%_{} = mapping) do
    AdditionalStatements.description(mapping)
  end

  @spec add_additional_statements(Schema.t(), Description.input()) :: Schema.t()
  def add_additional_statements(%_{} = mapping, predications) do
    AdditionalStatements.update(mapping, &Description.add(&1, predications))
  end

  @spec put_additional_statements(Schema.t(), Description.input()) :: Schema.t()
  def put_additional_statements(
        %_{__id__: id} = mapping,
        %Description{subject: subject} = description
      )
      when id != subject do
    AdditionalStatements.update(
      mapping,
      &Description.put(&1, Description.change_subject(description, id))
    )
  end

  def put_additional_statements(%_{} = mapping, predications) do
    AdditionalStatements.update(mapping, &Description.put(&1, predications))
  end

  @spec delete_additional_statements(Schema.t(), Description.input()) :: Schema.t()
  def delete_additional_statements(%_{} = mapping, predications) do
    AdditionalStatements.update(mapping, &Description.delete(&1, predications))
  end

  @spec delete_additional_predicates(
          Schema.t(),
          Statement.coercible_predicate() | [Statement.coercible_predicate()]
        ) :: Schema.t()
  def delete_additional_predicates(%_{} = mapping, properties) do
    AdditionalStatements.update(mapping, &Description.delete_predicates(&1, properties))
  end

  @spec clear_additional_statements(Schema.t(), opts :: keyword()) :: Schema.t()
  def clear_additional_statements(%_{} = mapping, opts \\ []) do
    AdditionalStatements.clear(mapping, opts)
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

  @spec to_rdf!(Schema.t(), opts :: keyword()) :: Graph.t()
  def to_rdf!(mapping, opts \\ []) do
    case to_rdf(mapping, opts) do
      {:ok, graph} -> graph
      {:error, error} -> raise error
    end
  end

  @spec schema(IRI.coercible()) :: module | [module] | nil
  def schema(iri) do
    iri
    |> RDF.iri()
    |> Registry.schema()
  end
end
