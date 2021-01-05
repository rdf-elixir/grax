defmodule Grax do
  alias Grax.{Schema, Validator, ValidationError}
  alias Grax.RDF.{Loader, Preloader, Mapper}

  alias RDF.{IRI, BlankNode, Graph, Description}

  @__id__property_access_error Schema.InvalidProperty.exception(
                                 property: :__id__,
                                 message:
                                   "__id__ can't be changed. Use build/2 to construct a new Grax.Schema mapping from another with a new id."
                               )

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

  def preload(%mapping_mod{} = mapping, graph, opts \\ []) do
    Preloader.call(mapping_mod, mapping, graph, setup_depth_preload_opts(opts))
  end

  def preload!(%mapping_mod{} = mapping, graph, opts \\ []) do
    Preloader.call(mapping_mod, mapping, graph, [
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
    value = if Schema.Property.value_set?(property_schema), do: List.wrap(value), else: value

    Validator
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
      if property_schema && Schema.Property.value_set?(property_schema),
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
