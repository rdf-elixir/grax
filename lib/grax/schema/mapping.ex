defmodule Grax.Schema.Mapping do
  @moduledoc false

  alias Grax.Schema.{AdditionalStatements, Property}
  alias Grax.RDF.Loader

  def from(value, to_schema) do
    if Grax.Schema.struct?(value) do
      with {:ok, extracted_values} <- extracted_values(value, to_schema) do
        Grax.build(to_schema, value.__id__, extracted_values)
      end
    else
      {:error, "invalid value #{inspect(value)}; only Grax.Schema structs are supported"}
    end
  end

  def from!(value, to_schema) do
    case from(value, to_schema) do
      {:ok, struct} -> struct
      {:error, error} -> raise error
    end
  end

  defp extracted_values(from, to_schema) do
    with {:ok, extracted_property_values} <- extracted_property_values(from, to_schema) do
      {:ok, extracted_property_values ++ extracted_field_values(from, to_schema)}
    end
  end

  defp extracted_property_values(%from_schema{} = from, to_schema) do
    from_schema_properties =
      Map.new(from_schema.__properties__(), fn {_, property_schema} ->
        {property_schema.iri, property_schema}
      end)

    RDF.Utils.map_while_ok(to_schema.__properties__(), fn {property, to_property_schema} ->
      with {:ok, value} <-
             fetch_value(from, from_schema_properties[to_property_schema.iri], to_property_schema) do
        {:ok, {property, value}}
      end
    end)
  end

  defp extracted_field_values(%from_schema{} = from, to_schema) do
    from_fields = Map.keys(from_schema.__custom_fields__())

    Enum.flat_map(to_schema.__custom_fields__(), fn {field, _} ->
      if field in from_fields do
        [{field, Map.get(from, field)}]
      else
        []
      end
    end)
  end

  defp fetch_value(from, %{iri: iri, name: from_name}, %{iri: iri} = to_property_schema) do
    value = Map.get(from, from_name)

    cond do
      Property.value_type(to_property_schema) == RDF.IRI -> {:ok, link_to_iri_mapping(value)}
      true -> {:ok, value}
    end
  end

  defp fetch_value(%{__additional_statements__: additional_statements}, _, %{iri: iri, type: type}) do
    if rdf_values = AdditionalStatements.get(additional_statements, iri) do
      Loader.map_values(rdf_values, type)
    else
      {:ok, nil}
    end
  end

  defp link_to_iri_mapping([%_{__id__: _} | _] = list), do: Enum.map(list, &link_to_iri_mapping/1)
  defp link_to_iri_mapping(list) when is_list(list), do: list
  defp link_to_iri_mapping(%_{__id__: id}), do: id
  defp link_to_iri_mapping(iri), do: iri
end
