defmodule Grax.Loader do
  @moduledoc false

  alias RDF.{Literal, IRI, BlankNode, Graph, Description}
  alias Grax.Link.Preloader
  alias Grax.InvalidValueError

  import RDF.Utils

  def call(mapping_mod, initial, %Graph{} = graph, opts) do
    id = initial.__id__
    description = Graph.description(graph, id) || Description.new(id)

    # TODO: Get rid of this! It's required currently for the case that the call received directly from load/4.
    opts =
      if Keyword.has_key?(opts, :depth) do
        Grax.setup_depth_preload_opts(opts)
      else
        opts
      end

    mapping_mod.__properties__(:data)
    |> Enum.reduce_while({:ok, initial}, fn {property, property_schema}, {:ok, mapping} ->
      cond do
        objects = Description.get(description, property_schema.iri) ->
          handle(objects, description, graph, property_schema)
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

  defp handle(objects, description, graph, property_schema)

  defp handle(objects, description, graph, %{from_rdf: from_rdf} = property_schema)
       when not is_nil(from_rdf) do
    apply(property_schema.mapping, from_rdf, [objects, description, graph])
  end

  defp handle(objects, _description, _graph, property_schema) do
    map_values(objects, property_schema.type)
  end

  defp map_values(values, {:set, _type}), do: map_while_ok(values, &map_value(&1))
  defp map_values([value], _type), do: map_value(value)
  defp map_values(values, _type), do: map_while_ok(values, &map_value(&1))

  defp map_value(%Literal{} = literal) do
    if Literal.valid?(literal) do
      {:ok, Literal.value(literal)}
    else
      {:error, InvalidValueError.exception(value: literal)}
    end
  end

  defp map_value(%IRI{} = iri), do: {:ok, iri}
  defp map_value(%BlankNode{} = bnode), do: {:ok, bnode}
end
