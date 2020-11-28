defmodule RDF.Mapping.ToRDF do
  @moduledoc false

  alias RDF.{Literal, XSD, Graph, Description}
  alias RDF.Mapping.Schema.TypeError

  def call(%mapping{} = struct, opts) do
    mapping.__property_map__()
    |> Enum.reduce_while(
      {:ok, Graph.new(), Description.new(mapping.iri(struct))},
      fn {property_name, property_iri}, {:ok, graph, description} ->
        case Map.get(struct, property_name) do
          nil ->
            {:cont, {:ok, graph, description}}

          values ->
            property_spec = mapping.__property_spec__(property_name)

            case map_values(values, property_spec.type) do
              {:ok, values} ->
                {:cont, {:ok, graph, Description.add(description, {property_iri, values})}}

              error ->
                {:halt, error}
            end
        end
      end
    )
    |> case do
      {:ok, graph, description} -> {:ok, Graph.add(graph, description)}
      error -> error
    end
  end

  defp map_values(value, nil) do
    {:ok, Literal.new(value)}
  end

  defp map_values(value, XSD.Numeric) do
    if is_number(value) or match?(%Decimal{}, value) do
      {:ok, Literal.new(value)}
    else
      {:error, TypeError.exception(value: value, type: XSD.Numeric)}
    end
  end

  defp map_values(value, type) do
    {:ok, type.new(value)}
  end
end
