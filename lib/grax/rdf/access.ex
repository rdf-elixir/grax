defmodule Grax.RDF.Access do
  @moduledoc !"""
             This encapsulates the access functions to the RDF data.

             It is intended to become an adapter to different types of data sources.
             """

  alias RDF.{Description, Graph, Query}
  alias Grax.Schema.LinkProperty
  alias Grax.Schema.Property.Polymorphic

  # TODO: this function becomes unnecessary when we depend on RDF.ex >= 0.12 as that's the default behaviour of Graph.description now
  # Dialyzer raises a warning with RDF.ex 0.12, since the fallback will never be used, but we need
  # the warning as long we support older versions, so we ignore the warning until we drop their support
  @dialyzer {:nowarn_function, description: 2}
  def description(graph, id) do
    Graph.description(graph, id) || Description.new(id)
  end

  def objects(_graph, description, property_iri)

  def objects(graph, description, {:inverse, property_iri}) do
    inverse_values(graph, description.subject, property_iri)
  end

  def objects(_graph, description, property_iri) do
    Description.get(description, property_iri)
  end

  def filtered_objects(graph, description, property_schema) do
    if objects = objects(graph, description, property_schema.iri) do
      case LinkProperty.value_type(property_schema) do
        %Polymorphic{types: class_mapping} ->
          Enum.reduce_while(objects, {:ok, []}, fn object, {:ok, objects} ->
            graph
            |> description(object)
            |> Polymorphic.determine_schema(class_mapping, property_schema)
            |> case do
              {:ok, nil} -> {:cont, {:ok, objects}}
              {:ok, _} -> {:cont, {:ok, [object | objects]}}
              {:error, _} = error -> {:halt, error}
            end
          end)

        _ ->
          {:ok, objects}
      end
    else
      {:ok, nil}
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
