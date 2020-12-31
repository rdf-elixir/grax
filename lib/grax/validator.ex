defmodule Grax.Validator do
  @moduledoc false

  alias Grax.{Link, ValidationError, InvalidIdError}
  alias Grax.Schema.{TypeError, RequiredPropertyMissing}
  alias RDF.{IRI, BlankNode, Literal, XSD}

  import ValidationError, only: [add_error: 3]

  def call(mapping, opts) do
    ValidationError.exception()
    |> check_subject_iri(mapping, opts)
    |> check_properties(mapping, opts)
    |> check_links(mapping, opts)
    |> case do
      %{errors: []} -> {:ok, mapping}
      validation -> {:error, validation}
    end
  end

  defp check_subject_iri(validation, %{__id__: %IRI{}}, _), do: validation
  defp check_subject_iri(validation, %{__id__: %BlankNode{}}, _), do: validation

  defp check_subject_iri(validation, %{__id__: id}, _) do
    add_error(validation, :__id__, InvalidIdError.exception(id: id))
  end

  defp check_properties(validation, %mapping_mod{} = mapping, opts) do
    mapping_mod.__properties__(:data)
    |> Enum.reduce(validation, fn {property, property_schema}, validation ->
      value = Map.get(mapping, property)
      check_property(validation, property, value, property_schema, opts)
    end)
  end

  defp check_links(validation, %mapping_mod{} = mapping, opts) do
    mapping_mod.__properties__(:link)
    |> Enum.reduce(validation, fn {link, link_schema}, validation ->
      value = Map.get(mapping, link)
      check_link(validation, link, value, link_schema, opts)
    end)
  end

  @doc false
  def check_property(validation, property, value, property_schema, opts) do
    type = property_schema.type

    validation
    |> check_cardinality(property, value, type, property_schema.required)
    |> check_datatype(property, value, type, opts)
  end

  @doc false
  def check_link(validation, link, value, link_schema, opts) do
    type = link_schema.type

    validation
    |> check_cardinality(link, value, type, false)
    |> check_resource_type(link, value, type, opts)
  end

  defp check_cardinality(validation, _, value, {:set, _}, false) when is_list(value),
    do: validation

  defp check_cardinality(validation, property, values, {:set, _}, true)
       when is_list(values) and length(values) == 0 do
    add_error(validation, property, RequiredPropertyMissing.exception(property: property))
  end

  defp check_cardinality(validation, _, values, {:set, _}, true) when is_list(values),
    do: validation

  defp check_cardinality(validation, _, %Link.NotLoaded{}, _, _),
    do: validation

  defp check_cardinality(validation, property, value, {:set, _} = type, _) do
    add_error(validation, property, TypeError.exception(value: value, type: type))
  end

  defp check_cardinality(validation, property, value, type, _) when is_list(value) do
    add_error(validation, property, TypeError.exception(value: value, type: type))
  end

  defp check_cardinality(validation, property, nil, _, true) do
    add_error(validation, property, RequiredPropertyMissing.exception(property: property))
  end

  defp check_cardinality(validation, _, _, _, _), do: validation

  defp check_datatype(validation, _, _, nil, _), do: validation
  defp check_datatype(validation, _, nil, _, _), do: validation
  defp check_datatype(validation, _, [], _, _), do: validation

  defp check_datatype(validation, property, values, {:set, type}, opts) do
    check_datatype(validation, property, values, type, opts)
  end

  defp check_datatype(validation, property, values, type, opts) when is_list(values) do
    Enum.reduce(values, validation, &check_datatype(&2, property, &1, type, opts))
  end

  defp check_datatype(validation, property, value, type, _opts) do
    if value |> in_value_space?(type) do
      validation
    else
      add_error(validation, property, TypeError.exception(value: value, type: type))
    end
  end

  defp in_value_space?(value, nil), do: value |> Literal.new() |> Literal.valid?()
  defp in_value_space?(%BlankNode{}, _), do: false
  defp in_value_space?(%IRI{}, IRI), do: true
  defp in_value_space?(_, IRI), do: false
  defp in_value_space?(value, XSD.String), do: is_binary(value)
  defp in_value_space?(%URI{}, XSD.AnyURI), do: true
  defp in_value_space?(_, XSD.AnyURI), do: false
  defp in_value_space?(value, XSD.Boolean), do: is_boolean(value)
  defp in_value_space?(value, XSD.Integer), do: is_integer(value)
  defp in_value_space?(value, XSD.Float), do: is_float(value)
  defp in_value_space?(value, XSD.Double), do: is_float(value)
  defp in_value_space?(%Decimal{}, XSD.Decimal), do: true
  defp in_value_space?(_, XSD.Decimal), do: false
  defp in_value_space?(%Decimal{}, XSD.Numeric), do: true
  defp in_value_space?(value, XSD.Numeric), do: is_number(value)

  defp in_value_space?(value, type) do
    cond do
      XSD.Numeric.datatype?(type) -> is_number(value) or match?(%Decimal{}, value)
      true -> true
    end
    |> if do
      value |> type.new(as_value: true) |> Literal.valid?()
    end
  end

  defp check_resource_type(validation, _, %Link.NotLoaded{}, _, _), do: validation
  defp check_resource_type(validation, _, nil, _, _), do: validation
  defp check_resource_type(validation, _, [], _, _), do: validation

  defp check_resource_type(validation, link, values, {:set, type}, opts) do
    check_resource_type(validation, link, values, type, opts)
  end

  defp check_resource_type(validation, link, values, type, opts) when is_list(values) do
    Enum.reduce(values, validation, &check_resource_type(&2, link, &1, type, opts))
  end

  defp check_resource_type(validation, link, %type{} = value, {:resource, type}, opts) do
    case call(value, opts) do
      {:ok, _} -> validation
      {:error, nested_validation} -> add_error(validation, link, nested_validation)
    end
  end

  defp check_resource_type(validation, link, value, type, _opts) do
    add_error(validation, link, TypeError.exception(value: value, type: type))
  end
end
