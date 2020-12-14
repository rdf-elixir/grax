defmodule RDF.Mapping.Validation do
  @moduledoc false

  alias RDF.Mapping.{ValidationError, InvalidSubjectIRIError}
  alias RDF.Mapping.Schema.TypeError
  alias RDF.{Literal, XSD}

  import ValidationError, only: [add_error: 3]

  def call(mapping, opts) do
    ValidationError.exception()
    |> check_subject_iri(mapping, opts)
    |> check_properties(mapping, opts)
    |> case do
      %{errors: []} -> {:ok, mapping}
      validation -> {:error, validation}
    end
  end

  defp check_subject_iri(validation, %{__iri__: iri}, _) when is_binary(iri),
    do: validation

  defp check_subject_iri(validation, %{__iri__: iri}, _) do
    add_error(validation, :__iri__, InvalidSubjectIRIError.exception(iri: iri))
  end

  defp check_properties(validation, %mapping_mod{} = mapping, opts) do
    mapping_mod.__property_spec__()
    |> Enum.reduce(validation, fn {property, property_spec}, validation ->
      value = Map.get(mapping, property)
      type = property_spec.type

      validation
      |> check_cardinality(property, value, type, opts)
      |> check_type(property, value, type, opts)
    end)
  end

  defp check_cardinality(validation, _, value, {:set, _}, _) when is_list(value),
    do: validation

  defp check_cardinality(validation, property, value, {:set, _} = type, _) do
    add_error(validation, property, TypeError.exception(value: value, type: type))
  end

  defp check_cardinality(validation, property, value, type, _) when is_list(value) do
    add_error(validation, property, TypeError.exception(value: value, type: type))
  end

  defp check_cardinality(validation, _, _, _, _), do: validation

  defp check_type(validation, _, _, nil, _), do: validation
  defp check_type(validation, _, nil, _, _), do: validation
  defp check_type(validation, _, [], _, _), do: validation

  defp check_type(validation, property, values, {:set, type}, opts) do
    check_type(validation, property, values, type, opts)
  end

  defp check_type(validation, property, values, type, opts) when is_list(values) do
    Enum.reduce(values, validation, &check_type(&2, property, &1, type, opts))
  end

  defp check_type(validation, property, value, type, _opts) do
    if value |> in_value_space?(type) do
      validation
    else
      add_error(validation, property, TypeError.exception(value: value, type: type))
    end
  end

  defp in_value_space?(value, nil), do: value |> Literal.new() |> Literal.valid?()
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
      type.new(value).literal.value == value
    end
  end
end
