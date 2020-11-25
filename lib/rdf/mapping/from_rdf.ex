defmodule RDF.Mapping.FromRDF do
  @moduledoc false

  alias RDF.{Term, IRI, Graph, Description}

  def call(mapping, initial, %IRI{} = iri, %Graph{} = graph, opts) do
    property_map = mapping.__property_map__()

    if description = Graph.description(graph, iri) do
      Enum.reduce_while(property_map, {:ok, initial}, fn {property, iri}, {:ok, struct} ->
        objects = Description.get(description, iri)

        handle(property, objects, description, graph, opts)
        |> case do
          {:ok, mapped_objects} ->
            {:cont, {:ok, Map.put(struct, property, mapped_objects)}}

          {:error, _} = error ->
            {:halt, error}
        end
      end)
    else
      {:error, "No description of #{inspect(iri)} found."}
    end
  end

  def call(mapping, initial, iri, %Graph{} = graph, opts) do
    if iri = IRI.new(iri) do
      call(mapping, initial, iri, graph, opts)
    else
      raise IRI.InvalidError, "Invalid IRI: #{inspect(iri)}"
    end
  end

  defp handle(property, objects, description, graph, opts)

  defp handle(_property, nil, _description, _graph, _opts), do: {:ok, nil}

  defp handle(_property, [object], _description, _graph, _opts) do
    {:ok, Term.value(object)}
  end

  defp handle(_property, objects, _description, _graph, _opts) do
    {:ok, Enum.map(objects, &Term.value/1)}
  end
end
