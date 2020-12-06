defmodule RDF.Mapping.FromRDF do
  @moduledoc false

  alias RDF.{Literal, IRI, Graph, Description}
  alias RDF.Mapping.Link.Preloader
  alias RDF.Mapping.{InvalidValueError, DescriptionNotFoundError}
  alias RDF.Mapping.Schema.TypeError

  import RDF.Utils

  def call(mapping_mod, initial, %IRI{} = iri, %Graph{} = graph, opts) do
    if description = Graph.description(graph, iri) do
      mapping_mod.__property_spec__()
      |> Enum.reduce_while({:ok, initial}, fn {property, property_spec}, {:ok, mapping} ->
        iri = mapping_mod.__property_map__(property)

        if objects = Description.get(description, iri) do
          handle(property, objects, description, graph, property_spec, opts)
          |> case do
            {:ok, mapped_objects} ->
              {:cont, {:ok, Map.put(mapping, property, mapped_objects)}}

            {:error, _} = error ->
              {:halt, error}
          end
        else
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
    else
      {:error, DescriptionNotFoundError.exception(resource: iri)}
    end
  end

  def call(mapping, initial, %IRI{} = iri, %Description{} = description, opts) do
    call(mapping, initial, iri, Graph.new(description), opts)
  end

  def call(_, _, %IRI{}, invalid, _) do
    raise ArgumentError, "invalid input data: #{inspect(invalid)}"
  end

  def call(mapping, initial, iri, data, opts) do
    if iri = IRI.new(iri) do
      call(mapping, initial, iri, data, opts)
    else
      raise ArgumentError, "invalid IRI: #{inspect(iri)}"
    end
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

  defp map_values(values, type, _, _, _) do
    {:error, TypeError.exception(value: values, type: type)}
  end

  defp map_value(%Literal{} = literal, type, _property_spec, _graph, _opts) do
    cond do
      not Literal.valid?(literal) ->
        {:error, InvalidValueError.exception(value: literal)}

      is_nil(type) or Literal.is_a?(literal, type) ->
        {:ok, Literal.value(literal)}

      true ->
        {:error, TypeError.exception(value: literal, type: type)}
    end
  end
end
