defmodule RDF.Mapping.ToRDF do
  @moduledoc false

  alias RDF.{IRI, Graph, Description}

  def call(%mapping{} = struct, opts) do
    mapping.__property_map__()
    |> Enum.reduce_while(
      {:ok, Graph.new(), Description.new(mapping.iri(struct))},
      fn {property_name, property_iri}, {:ok, graph, description} ->
        case Map.get(struct, property_name) do
          nil ->
            {:cont, {:ok, graph, description}}

          values ->
            {:cont, {:ok, graph, Description.add(description, {property_iri, values})}}
        end
      end
    )
    |> case do
      {:ok, graph, description} -> {:ok, Graph.add(graph, description)}
      error -> error
    end
  end
end
