defmodule Grax.RDF.Loader do
  @moduledoc false

  alias RDF.{Literal, IRI, BlankNode, Graph, Description}
  alias Grax.Schema.AdditionalStatements
  alias Grax.RDF.Preloader
  alias Grax.InvalidValueError

  import Grax.RDF.Access
  import RDF.Utils

  def call(schema, initial, %Graph{} = graph, opts) do
    id = initial.__id__

    {description, opts} = Keyword.pop_lazy(opts, :description, fn -> description(graph, id) end)

    # TODO: Get rid of this! It's required currently for the case that the call received directly from load/4.
    opts =
      if Keyword.has_key?(opts, :depth) do
        Grax.setup_depth_preload_opts(opts)
      else
        opts
      end

    mapping = load_additional_statements(schema, description, initial)

    with {:ok, mapping} <-
           load_properties(schema.__properties__(:data), mapping, graph, description),
         {:ok, mapping} <-
           init_custom_fields(schema, mapping, graph, description) do
      Preloader.call(schema, mapping, graph, description, opts)
    end
  end

  def call(mapping, initial, %Description{} = description, opts) do
    call(mapping, initial, Graph.new(description), opts)
  end

  def call(_, _, invalid, _) do
    raise ArgumentError, "invalid input data: #{inspect(invalid)}"
  end

  def load_additional_statements(schema, description, initial) do
    if schema.__load_additional_statements__?() do
      %{
        initial
        | __additional_statements__:
            additional_statements(schema.__domain_properties__(), description, initial)
      }
    else
      initial
    end
  end

  defp additional_statements(properties, description, initial) do
    Enum.reduce(description, initial.__additional_statements__, fn
      {_, p, o}, additional_statements ->
        if p in properties do
          additional_statements
        else
          AdditionalStatements.add(additional_statements, p, o)
        end
    end)
  end

  def load_properties(property_schemas, initial, graph, description) do
    Enum.reduce_while(property_schemas, {:ok, initial}, fn
      {property, property_schema}, {:ok, mapping} ->
        case filtered_objects(graph, description, property_schema) do
          {:ok, objects} ->
            add_objects(mapping, property, objects, description, graph, property_schema)

          {:error, _} = error ->
            {:halt, error}
        end
    end)
  end

  def add_objects(mapping, property, objects, description, graph, property_schema)

  def add_objects(mapping, _, nil, _, _, _), do: {:cont, {:ok, mapping}}

  def add_objects(mapping, property, objects, description, graph, property_schema) do
    case handle(objects, description, graph, property_schema) do
      {:ok, mapped_objects} ->
        {:cont, {:ok, Map.put(mapping, property, mapped_objects)}}

      {:error, _} = error ->
        {:halt, error}
    end
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

  defp map_values(values, {:list_set, _type}), do: map_while_ok(values, &map_value(&1))
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
