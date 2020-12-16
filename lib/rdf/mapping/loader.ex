defmodule RDF.Mapping.Loader do
  @moduledoc false

  alias RDF.{Literal, IRI, BlankNode, Graph, Description}
  alias RDF.Mapping.Link.Preloader
  alias RDF.Mapping.InvalidValueError

  import RDF.Utils

  def call(mapping_mod, initial, %Graph{} = graph, opts) do
    id = initial.__id__
    description = Graph.description(graph, id) || Description.new(id)

    mapping_mod.__property_spec__()
    |> Enum.reduce_while({:ok, initial}, fn {property, property_spec}, {:ok, mapping} ->
      property_iri = mapping_mod.__property_map__(property)

      cond do
        objects = Description.get(description, property_iri) ->
          handle(property, objects, description, graph, property_spec, opts)
          |> case do
            {:ok, mapped_objects} ->
              {:cont, {:ok, Map.put(mapping, property, mapped_objects)}}

            {:error, _} = error ->
              {:halt, error}
          end

        true ->
          {:cont, {:ok, mapping}}
      end
    end)
    |> case do
      {:ok, mapping} ->
        Preloader.call(
          mapping_mod,
          mapping,
          graph,
          description,
          mapping_mod.__link_spec__(),
          opts
        )

      error ->
        error
    end
  end

  def call(mapping, initial, %Description{} = description, opts) do
    call(mapping, initial, Graph.new(description), opts)
  end

  def call(_, _, invalid, _) do
    raise ArgumentError, "invalid input data: #{inspect(invalid)}"
  end

  defp handle(property, objects, description, graph, property_spec, opts)

  defp handle(_property, objects, _description, graph, property_spec, opts) do
    map_values(objects, property_spec.type, property_spec, graph, opts)
  end

  defp map_values(values, {:set, type}, property_spec, graph, opts) do
    map_while_ok(values, &map_value(&1, type, property_spec, graph, opts))
  end

  defp map_values([value], type, property_spec, graph, opts) do
    map_value(value, type, property_spec, graph, opts)
  end

  defp map_values(values, type, property_spec, graph, opts) do
    map_while_ok(values, &map_value(&1, type, property_spec, graph, opts))
  end

  defp map_value(%Literal{} = literal, _type, _property_spec, _graph, _opts) do
    if Literal.valid?(literal) do
      {:ok, Literal.value(literal)}
    else
      {:error, InvalidValueError.exception(value: literal)}
    end
  end
end
