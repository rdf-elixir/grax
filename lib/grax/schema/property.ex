defmodule Grax.Schema.Property do
  @moduledoc false

  alias Grax.Schema.Type

  @shared_attrs [:schema, :name, :iri, :type, :cardinality]

  def shared_attrs, do: @shared_attrs

  def init(property_schema, schema, name, iri, _opts) when is_atom(name) do
    struct!(property_schema,
      schema: schema,
      name: name,
      iri: normalize_iri(iri)
    )
  end

  defp normalize_iri({:inverse, iri}), do: {:inverse, RDF.iri!(iri)}
  defp normalize_iri(iri), do: RDF.iri!(iri)

  def value_set?(%{type: type}), do: value_set?(type)
  def value_set?(type), do: Type.set?(type)

  def default({:list_set, _}), do: []
  def default(_), do: nil

  def type_with_cardinality(name, opts, property_type) do
    type_with_cardinality(
      name,
      opts[:type],
      Keyword.get(opts, :required, false),
      property_type
    )
  end

  def type_with_cardinality(name, type, false, property_type) do
    case initial_value_type(type, property_type) do
      {:ok, type, card} ->
        {type, card}

      {:ok, type} ->
        {type, nil}

      {:error, nil} ->
        raise ArgumentError, "invalid type definition #{inspect(type)} for property #{name}"

      {:error, error} ->
        raise ArgumentError, "invalid type definition for property #{name}: #{error}"
    end
  end

  def type_with_cardinality(name, type, true, property_type) do
    with {type, cardinality} <- type_with_cardinality(name, type, false, property_type) do
      cond do
        not Type.set?(type) ->
          {type, 1}

        is_nil(cardinality) ->
          {type, {:min, 1}}

        true ->
          raise ArgumentError,
                "property #{name}: required option is not allowed when cardinality constraints are given"
      end
    end
  end

  defp initial_value_type({:list_set, type, cardinality}, property_type) do
    with {:ok, inner_type} <- property_type.initial_value_type(type) do
      {:ok, {:list_set, inner_type}, cardinality}
    end
  end

  defp initial_value_type(type, property_type) do
    property_type.initial_value_type(type)
  end

  def value_type(%mod{} = schema), do: mod.value_type(schema)
end

defmodule Grax.Schema.DataProperty do
  @moduledoc false

  alias Grax.Schema.Property
  alias Grax.Datatype
  alias RDF.Literal

  defstruct Property.shared_attrs() ++ [:default, :from_rdf, :to_rdf]

  @default_type :any

  def new(schema, name, iri, opts) do
    {type, cardinality} = Property.type_with_cardinality(name, opts, __MODULE__)

    __MODULE__
    |> Property.init(schema, name, iri, opts)
    |> struct!(
      type: type,
      cardinality: cardinality,
      default: init_default(type, opts[:default]),
      from_rdf: normalize_custom_mapping_fun(opts[:from_rdf], schema),
      to_rdf: normalize_custom_mapping_fun(opts[:to_rdf], schema)
    )
  end

  def initial_value_type(nil), do: initial_value_type(@default_type)
  def initial_value_type(type), do: Datatype.get(type)

  defp init_default(type, nil), do: Property.default(type)

  defp init_default({:list_set, _}, _),
    do: raise(ArgumentError, "the :default option is not supported on sets")

  defp init_default(nil, default), do: default

  defp init_default(type, default) do
    if Literal.new(default) |> Literal.is_a?(type) do
      default
    else
      raise ArgumentError, "default value #{inspect(default)} doesn't match type #{inspect(type)}"
    end
  end

  @doc false
  def normalize_custom_mapping_fun(nil, _), do: nil
  def normalize_custom_mapping_fun({_, _} = mod_fun, _), do: mod_fun
  def normalize_custom_mapping_fun(fun, schema), do: {schema, fun}

  def value_type(%__MODULE__{} = schema), do: do_value_type(schema.type)

  defp do_value_type({:list_set, type}), do: do_value_type(type)
  defp do_value_type(type), do: type
end

defmodule Grax.Schema.LinkProperty do
  @moduledoc false

  alias Grax.Schema.Property

  defstruct Property.shared_attrs() ++ [:preload, :on_type_mismatch]

  def new(schema, name, iri, opts) do
    {type, cardinality} = Property.type_with_cardinality(name, opts, __MODULE__)

    if Keyword.has_key?(opts, :default) do
      raise ArgumentError, "the :default option is not supported on links"
    end

    __MODULE__
    |> Property.init(schema, name, iri, opts)
    |> struct!(
      type: type,
      cardinality: cardinality,
      preload: opts[:preload],
      on_type_mismatch: init_on_type_mismatch(opts[:on_type_mismatch])
    )
  end

  @valid_on_type_mismatch_values ~w[ignore error]a

  defp init_on_type_mismatch(nil), do: :ignore
  defp init_on_type_mismatch(value) when value in @valid_on_type_mismatch_values, do: value

  defp init_on_type_mismatch(value) do
    raise ArgumentError,
          "invalid on_type_mismatch value: #{inspect(value)} (valid values: #{inspect(@valid_on_type_mismatch_values)})"
  end

  def initial_value_type(nil), do: {:error, "type missing"}

  def initial_value_type(class_mapping) when is_map(class_mapping) do
    with {:ok, polymorphic} <- Property.Polymorphic.new(class_mapping) do
      {:ok, {:resource, polymorphic}}
    end
  end

  def initial_value_type(schema), do: {:ok, {:resource, schema}}

  def value_type(%__MODULE__{} = schema), do: do_value_type(schema.type)
  def value_type(_), do: nil
  defp do_value_type({:list_set, type}), do: do_value_type(type)
  defp do_value_type({:resource, type}), do: type
  defp do_value_type(_), do: nil

  def polymorphic_type?(schema) do
    match?(%Property.Polymorphic{}, value_type(schema))
  end
end
