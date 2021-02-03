defmodule Grax.Schema.Property do
  @moduledoc false

  @shared_attrs [:schema, :name, :iri, :type, :from_rdf, :to_rdf]

  def shared_attrs, do: @shared_attrs

  def init(property_schema, schema, name, iri, opts) when is_atom(name) do
    struct!(property_schema,
      schema: schema,
      name: name,
      iri: normalize_iri(iri),
      from_rdf: opts[:from_rdf],
      to_rdf: opts[:to_rdf]
    )
  end

  defp normalize_iri({:inverse, iri}), do: {:inverse, RDF.iri!(iri)}
  defp normalize_iri(iri), do: RDF.iri!(iri)

  def value_set?(%{type: type}), do: value_set?(type)
  def value_set?({:set, _}), do: true
  def value_set?(_), do: false

  def default({:set, _}), do: []
  def default(_), do: nil
end

defmodule Grax.Schema.DataProperty do
  @moduledoc false

  alias Grax.Schema.Property
  alias Grax.Datatype
  alias RDF.Literal

  defstruct Property.shared_attrs() ++ [:required, :default]

  @default_type :any

  def new(schema, name, iri, opts) do
    type = init_type(name, opts[:type])

    __MODULE__
    |> Property.init(schema, name, iri, opts)
    |> struct!(
      type: type,
      default: init_default(type, opts[:default]),
      required: Keyword.get(opts, :required, false)
    )
  end

  defp init_type(name, nil), do: init_type(name, @default_type)

  defp init_type(name, type) do
    case Datatype.get(type) do
      {:ok, type} ->
        type

      {:error, error} ->
        raise ArgumentError,
              "invalid type definition #{inspect(type)} for property #{name}: #{error}"
    end
  end

  defp init_default(type, nil), do: Property.default(type)

  defp init_default({:set, _}, _),
    do: raise(ArgumentError, "the :default option is not supported on sets")

  defp init_default(nil, default), do: default

  defp init_default(type, default) do
    if Literal.new(default) |> Literal.is_a?(type) do
      default
    else
      raise ArgumentError, "default value #{inspect(default)} doesn't match type #{inspect(type)}"
    end
  end
end

defmodule Grax.Schema.LinkProperty do
  @moduledoc false

  alias Grax.Schema.Property
  alias Grax.Link

  defstruct Property.shared_attrs() ++ [:preload, :on_type_mismatch]

  def new(schema, name, iri, opts) do
    cond do
      Keyword.has_key?(opts, :default) ->
        raise ArgumentError, "the :default option is not supported on links"

      Keyword.has_key?(opts, :required) ->
        raise ArgumentError, "the :required option is not supported on links"

      true ->
        __MODULE__
        |> Property.init(schema, name, iri, opts)
        |> struct!(
          type: init_type(name, opts[:type]),
          preload: opts[:preload],
          on_type_mismatch: init_on_type_mismatch(opts[:on_type_mismatch])
        )
    end
  end

  @valid_on_type_mismatch_values ~w[ignore error]a

  defp init_on_type_mismatch(nil), do: :ignore
  defp init_on_type_mismatch(value) when value in @valid_on_type_mismatch_values, do: value

  defp init_on_type_mismatch(value) do
    raise ArgumentError,
          "invalid on_type_mismatch value: #{inspect(value)} (valid values: #{
            inspect(@valid_on_type_mismatch_values)
          })"
  end

  defp init_type(name, nil) do
    raise ArgumentError, "type missing for property #{name}"
  end

  defp init_type(name, type) do
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

  defp resource_type(class_mapping) when is_map(class_mapping) do
    {:ok,
     {:resource,
      Map.new(class_mapping, fn
        {nil, schema} -> {nil, schema}
        {class, schema} -> {RDF.iri(class), schema}
      end)}}
  end

  defp resource_type(schema) do
    {:ok, {:resource, schema}}
  end

  def default(%__MODULE__{} = link_schema) do
    %Link.NotLoaded{
      __owner__: link_schema.schema,
      __field__: link_schema.name
    }
  end
end
