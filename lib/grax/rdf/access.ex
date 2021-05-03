defmodule Grax.RDF.Access do
  @moduledoc !"""
             This encapsulates the access functions to the RDF data.

             It is intended to become an adapter to different types of data sources.
             """

  alias RDF.{Description, Graph, Query}
  alias Grax.Schema.LinkProperty
  alias Grax.InvalidResourceTypeError

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
    case LinkProperty.value_type(property_schema) do
      %{} = class_mapping when not is_struct(class_mapping) ->
        graph
        |> objects(description, property_schema.iri)
        |> Enum.reduce_while({:ok, []}, fn object, {:ok, objects} ->
          description = description(graph, object)

          case determine_schema(
                 description[RDF.type()],
                 class_mapping,
                 property_schema.on_type_mismatch
               ) do
            {:ok, nil} -> {:cont, {:ok, objects}}
            {:ok, _} -> {:cont, {:ok, [object | objects]}}
            {:error, _} = error -> {:halt, error}
          end
        end)

      _ ->
        {:ok, objects(graph, description, property_schema.iri)}
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

  def determine_schema(types, class_mapping, on_type_mismatch) do
    types
    |> List.wrap()
    |> Enum.reduce([], fn class, candidates ->
      case class_mapping[class] do
        nil -> candidates
        schema -> [schema | candidates]
      end
    end)
    |> do_determine_schema(types, class_mapping, on_type_mismatch)
  end

  defp do_determine_schema([schema], _, _, _), do: {:ok, schema}

  defp do_determine_schema([], types, class_mapping, on_type_mismatch) do
    case class_mapping[nil] do
      nil ->
        case on_type_mismatch do
          :ignore ->
            {:ok, nil}

          :error ->
            {:error, InvalidResourceTypeError.exception(type: :no_match, resource_types: types)}
        end

      schema ->
        {:ok, schema}
    end
  end

  defp do_determine_schema(_, types, _, _) do
    {:error, InvalidResourceTypeError.exception(type: :multiple_matches, resource_types: types)}
  end
end
