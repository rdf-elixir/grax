defmodule Grax.RDF.Access do
  @moduledoc !"""
             This encapsulates the access functions to the RDF data.

             It is intended to become an adapter to different types of data sources.
             """

  alias RDF.{Description, Graph, Query}
  alias Grax.Schema.LinkProperty

  def description(graph, id) do
    Graph.description(graph, id)
  end

  def objects(_graph, description, property_iri)

  def objects(graph, description, {:inverse, property_iri}) do
    inverse_values(graph, description.subject, property_iri)
  end

  def objects(_graph, description, property_iri) do
    Description.get(description, property_iri)
  end

  def filtered_objects(graph, description, %property_type{} = property_schema) do
    case objects(graph, description, property_schema.iri) do
      nil ->
        {:ok, nil}

      objects when property_type == LinkProperty ->
        Enum.reduce_while(objects, {:ok, []}, fn object, {:ok, objects} ->
          case LinkProperty.determine_schema(property_schema, description(graph, object)) do
            {:ok, nil} -> {:cont, {:ok, objects}}
            {:ok, _} -> {:cont, {:ok, [object | objects]}}
            {:error, _} = error -> {:halt, error}
          end
        end)
        |> case do
          {:ok, objects} -> {:ok, Enum.reverse(objects)}
          other -> other
        end

      # We currently have no filter logic on data properties
      objects ->
        {:ok, objects}
    end
  end

  defp inverse_values(graph, subject, property) do
    {:object?, property, subject}
    |> Query.execute!(graph)
    |> case do
      [] -> nil
      results -> Enum.map(results, &Map.fetch!(&1, :object))
    end
  end
end
