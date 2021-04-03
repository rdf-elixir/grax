defmodule Grax do
  @moduledoc """
  The Grax API.

  For now there is no API documentation.
  Read about the API in the guide [here](https://rdf-elixir.dev/grax/api.html).
  """

  alias Grax.{Schema, Id, Link, Validator, ValidationError}
  alias Grax.RDF.{Loader, Preloader, Mapper}

  alias RDF.{IRI, BlankNode, Graph}

  import RDF.Utils

  @__id__property_access_error Schema.InvalidProperty.exception(
                                 property: :__id__,
                                 message:
                                   "__id__ can't be changed. Use build/2 to construct a new Grax.Schema mapping from another with a new id."
                               )

  def build(mod, %IRI{} = id), do: {:ok, do_build(mod, id)}
  def build(mod, %BlankNode{} = id), do: {:ok, do_build(mod, id)}
  def build(mod, %Id.Schema{} = id_schema), do: build(mod, id_schema, %{})

  def build(mod, %{__id__: id} = initial), do: build(mod, id, Map.delete(initial, :__id__))

  def build(mod, initial) when is_map(initial) or is_list(initial) do
    if id_schema = mod.__id_schema__() do
      build(mod, id_schema, initial)
    else
      raise ArgumentError, "id missing and no id schema found"
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
    with {:ok, id} <- Id.Schema.generate_id(id_schema, initial) do
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
    with {:ok, initial} <- build(mod, id) do
      Loader.call(mod, initial, graph, opts)
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

  def put(%schema{} = mapping, property, value) do
    if Schema.has_field?(schema, property) do
      cond do
        property_schema = schema.__property__(property) ->
          validation =
            case property_schema.__struct__ do
              Schema.DataProperty -> :check_property
              Schema.LinkProperty -> :check_link
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

  def put!(%schema{} = mapping, property, value) do
    struct!(mapping, [{property, normalize_value(value, schema.__property__(property))}])
  end

  def put!(%_{} = mapping, values) do
    Enum.reduce(values, mapping, fn
      {property, value}, mapping ->
        put!(mapping, property, value)
    end)
  end

  defp normalize_value(%Link.NotLoaded{} = value, _), do: value
  defp normalize_value(Link.NotLoaded, property_schema), do: Link.NotLoaded.new(property_schema)

  defp normalize_value(value, property_schema) do
    do_normalize_value(
      if(is_list(value), do: Enum.uniq(value), else: value),
      Schema.Property.value_set?(property_schema)
    )
  end

  defp do_normalize_value(value, true), do: List.wrap(value)
  defp do_normalize_value([value], false), do: value
  defp do_normalize_value(value, false), do: value

  defp build_linked(values, %Schema.LinkProperty{} = property_schema) when is_list(values) do
    map_while_ok(values, &build_linked(&1, property_schema))
  end

  defp build_linked(%{} = value, %Schema.LinkProperty{} = property_schema) do
    if Map.has_key?(value, :__struct__) do
      {:ok, value}
    else
      if resource_type = Schema.LinkProperty.value_type(property_schema) do
        resource_type.build(value)
      else
        raise ArgumentError,
              "unable to determine value type of property #{inspect(property_schema)}"
      end
    end
  end

  defp build_linked(value, _), do: {:ok, value}

  @spec validate(struct, opts :: Keyword) :: {:ok, struct} | {:error, ValidationError.t()}
  def validate(%_{} = mapping, opts \\ []) do
    Validator.call(mapping, opts)
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
    Mapper.call(mapping, opts)
  end
end
