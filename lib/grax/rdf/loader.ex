defmodule Grax.RDF.Loader do
  @moduledoc false

  alias RDF.{Literal, IRI, BlankNode, Graph, Description}
  alias Grax.RDF.Preloader
  alias Grax.{Link, InvalidValueError}

  import RDF.Utils

  def call(schema, initial, %Graph{} = graph, opts) do
    id = initial.__id__

    {description, opts} =
      Keyword.pop(opts, :description, Graph.description(graph, id) || Description.new(id))

    # TODO: Get rid of this! It's required currently for the case that the call received directly from load/4.
    opts =
      if Keyword.has_key?(opts, :depth) do
        Grax.setup_depth_preload_opts(opts)
      else
        opts
      end

    with {:ok, mapping} <-
           load_data_properties(schema, initial, graph, description),
         {:ok, mapping} <-
           init_link_properties(schema, mapping),
         {:ok, mapping} <-
           init_custom_fields(schema, mapping, graph, description) do
      Preloader.call(
        schema,
        mapping,
        graph,
        description,
        opts
      )
    end
  end

  def call(mapping, initial, %Description{} = description, opts) do
    call(mapping, initial, Graph.new(description), opts)
  end

  def call(_, _, invalid, _) do
    raise ArgumentError, "invalid input data: #{inspect(invalid)}"
  end

  defp load_data_properties(schema, initial, graph, description) do
    schema.__properties__(:data)
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
  end

  @doc false
  def init_link_properties(%schema{} = mapping) do
    with {:ok, mapping} <- init_link_properties(schema, mapping) do
      mapping
    end
  end

  defp init_link_properties(schema, mapping) do
    {:ok,
     schema.__properties__(:link)
     |> Enum.reduce(mapping, fn {link, link_schema}, mapping ->
       Map.put(mapping, link, Link.NotLoaded.new(link_schema))
     end)}
  end

  defp init_custom_fields(schema, mapping, graph, description) do
    schema.__custom_fields__()
    |> Enum.reduce_while({:ok, mapping}, fn
      {_, %{from_rdf: nil}}, mapping ->
        {:cont, mapping}

      {field, %{from_rdf: {mod, fun}}}, {:ok, mapping} ->
        case apply(mod, fun, [description, graph]) do
          {:ok, result} ->
            {:cont, {:ok, Map.put(mapping, field, result)}}

          error ->
            {:halt, error}
        end
    end)
  end

  defp handle(objects, description, graph, property_schema)

  defp handle(objects, description, graph, %{from_rdf: {mod, fun}}) do
    apply(mod, fun, [objects, description, graph])
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
