defmodule Grax.Schema.Property do
  @moduledoc false

  alias Grax.Schema.Type
  import Grax.Schema.Type

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

  def default({list_type, _}) when is_list_type(list_type), do: []
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

  defp initial_value_type({list_type, type, cardinality}, property_type)
       when is_list_type(list_type) do
    with {:ok, inner_type} <- property_type.initial_value_type(type) do
      {:ok, {list_type, inner_type}, cardinality}
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

  import Grax.Schema.Type

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

  defp init_default({list_type, _}, _) when is_list_type(list_type),
    do: raise(ArgumentError, "the :default option is not supported on list types")

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

  defp do_value_type({list_type, type}) when is_list_type(list_type), do: do_value_type(type)
  defp do_value_type(type), do: type
end

defmodule Grax.Schema.LinkProperty do
  @moduledoc false

  alias Grax.Schema.Property
  alias Grax.Schema.LinkProperty.Union
  alias Grax.Schema.Inheritance
  alias Grax.InvalidResourceTypeError

  import Grax.Schema.Type

  defstruct Property.shared_attrs() ++
              [:preload, :polymorphic, :on_rdf_type_mismatch, :on_missing_description]

  def new(schema, name, iri, opts) do
    {type, cardinality} = Property.type_with_cardinality(name, opts, __MODULE__)

    if Keyword.has_key?(opts, :default) do
      raise ArgumentError, "the :default option is not supported on links"
    end

    union_type? = match?(%Union{}, do_value_type(type))

    __MODULE__
    |> Property.init(schema, name, iri, opts)
    |> struct!(
      type: type,
      cardinality: cardinality,
      polymorphic: Keyword.get(opts, :polymorphic, true),
      preload: opts[:preload],
      on_rdf_type_mismatch: init_on_rdf_type_mismatch(union_type?, opts[:on_rdf_type_mismatch]),
      on_missing_description: init_on_missing_description(opts[:on_missing_description])
    )
  end

  @valid_on_rdf_type_mismatch_values ~w[ignore force error]a

  defp init_on_rdf_type_mismatch(false, nil), do: :force
  defp init_on_rdf_type_mismatch(true, nil), do: :ignore

  defp init_on_rdf_type_mismatch(true, :force) do
    raise ArgumentError,
          "on_rdf_type_mismatch: :force is not supported on union types; use a nil fallback instead to enforce a certain schema"
  end

  defp init_on_rdf_type_mismatch(_, value) when value in @valid_on_rdf_type_mismatch_values,
    do: value

  defp init_on_rdf_type_mismatch(_, value) do
    raise ArgumentError,
          "invalid on_rdf_type_mismatch value: #{inspect(value)} (valid values: #{inspect(@valid_on_rdf_type_mismatch_values)})"
  end

  @valid_on_missing_description_values ~w[empty_schema use_rdf_node]a

  defp init_on_missing_description(nil), do: :empty_schema

  defp init_on_missing_description(valid) when valid in @valid_on_missing_description_values,
    do: valid

  defp init_on_missing_description(invalid) do
    raise ArgumentError,
          "invalid on_missing_description value: #{inspect(invalid)} (valid values: #{inspect(@valid_on_missing_description_values)})"
  end

  def initial_value_type(nil), do: {:error, "type missing"}

  def initial_value_type(class_mapping) when is_map(class_mapping) or is_list(class_mapping) do
    with {:ok, union} <- Union.new(class_mapping) do
      {:ok, {:resource, union}}
    end
  end

  def initial_value_type(schema), do: {:ok, {:resource, schema}}

  def value_type(%__MODULE__{} = schema), do: do_value_type(schema.type)
  def value_type(_), do: nil
  defp do_value_type({list_type, type}) when is_list_type(list_type), do: do_value_type(type)
  defp do_value_type({:resource, type}), do: type
  defp do_value_type(_), do: nil

  def union_type?(schema) do
    match?(%Union{}, value_type(schema))
  end

  def determine_schema(property_schema, description) do
    determine_schema(property_schema, value_type(property_schema), description)
  end

  def determine_schema(property_schema, %Union{types: class_mapping}, description) do
    Union.determine_schema(description, class_mapping, property_schema)
  end

  def determine_schema(%{polymorphic: false, on_rdf_type_mismatch: :force}, schema, _) do
    {:ok, schema}
  end

  def determine_schema(%{polymorphic: false} = property_schema, schema, description) do
    if Inheritance.matches_rdf_types?(description, schema) do
      {:ok, schema}
    else
      case property_schema.on_rdf_type_mismatch do
        :ignore ->
          {:ok, nil}

        :error ->
          {:error,
           InvalidResourceTypeError.exception(
             type: :no_match,
             resource_types: description[RDF.type()]
           )}
      end
    end
  end

  def determine_schema(property_schema, schema, description) do
    Inheritance.determine_schema(description, schema, property_schema)
  end
end
