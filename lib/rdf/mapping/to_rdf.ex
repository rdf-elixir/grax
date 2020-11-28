defmodule RDF.Mapping.ToRDF do
  @moduledoc false

  alias RDF.{Literal, Graph, Description}

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

            {:cont,
             {:ok, graph,
              Description.add(description, {property_iri, map_values(values, property_spec.type)})}}
        end
      end
    )
    |> case do
      {:ok, graph, description} -> {:ok, Graph.add(graph, description)}
      error -> error
    end
  end

  defp map_values(value, nil) do
    Literal.new(value)
  end

  defp map_values(value, type) do
    type.new(value)
  end
end
