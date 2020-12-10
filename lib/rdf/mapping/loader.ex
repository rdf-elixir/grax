defmodule RDF.Mapping.Loader do
  @moduledoc false

  alias RDF.{Literal, IRI, Graph, Description}
  alias RDF.Mapping.Link.Preloader
  alias RDF.Mapping.{InvalidValueError, DescriptionNotFoundError}
  alias RDF.Mapping.Schema.TypeError

  import RDF.Utils

  #  def call(mapping, %Graph{} = graph, %IRI{} = iri, initial, opts) do
  #    property_map = mapping.__property_map__()
  #
  #    if description = Graph.description(graph, iri) do
  #      Enum.reduce_while(property_map, {:ok, initial}, fn {property, iri}, {:ok, struct} ->
  #        # TODO: Remove this - it should be handled differently
  #        {iri, expect_list} =
  #          case iri do
  #            [iri] -> {iri, true}
  #            iri -> {iri, false}
  #          end
  #
  #        objects = Description.get(description, iri)
  #        # TODO: if nil:
  #        #   - look for defaults? This can/should be handled via struct
  #        mapping.handle_from_rdf(
  #          property,
  #          objects,
  #          description,
  #          graph,
  #          opts
  #        )
  #        |> case do
  #          {:ok, mapped_objects} when not expect_list and is_list(mapped_objects) ->
  #            # TODO: test this
  #            {:halt, {:error, "expected a single value, but got a list"}}
  #
  #          {:ok, mapped_objects} ->
  #            mapped_objects = if expect_list, do: List.wrap(mapped_objects), else: mapped_objects
  #            {:cont, {:ok, Map.put(struct, property, mapped_objects)}}
  #
  #          {:error, _} = error ->
  #            {:halt, error}
  #        end
  #      end)
  #    else
  #      {:error, "No description of #{inspect(iri)} found."}
  #    end
  #  end

  def call(mapping_mod, initial, %IRI{} = iri, %Graph{} = graph, opts) do
    description = Graph.description(graph, iri) || Description.new(iri)

    mapping_mod.__property_spec__()
    |> Enum.reduce_while({:ok, initial}, fn {property, property_spec}, {:ok, mapping} ->
      property_iri = mapping_mod.__property_map__(property)

      if objects = Description.get(description, property_iri) do
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

  # TODO: handle IRIs and bnodes for non-link properties
  #  defp map_value(%IRI{} = iri, {:resource, module}, property_spec, graph, opts) do
  #  end
  #  defp map_value(%BlankNode{} = bnode, {:resource, module}, property_spec, graph, opts) do
  #  end
end
