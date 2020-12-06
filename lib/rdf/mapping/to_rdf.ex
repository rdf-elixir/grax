defmodule RDF.Mapping.ToRDF do
  @moduledoc false

  alias RDF.{IRI, Literal, XSD, Graph, Description}
  alias RDF.Mapping.Link
  alias RDF.Mapping.Schema.TypeError

  def call(%mapping{} = struct, opts) do
    mapping.__property_map__()
    |> Enum.reduce_while(
      {:ok, Description.new(mapping.iri(struct)), Graph.new()},
      fn {property_name, property_iri}, {:ok, description, graph} ->
        case Map.get(struct, property_name) do
          nil ->
            {:cont, {:ok, description, graph}}

          %Link.NotLoaded{} ->
            {:cont, {:ok, description, graph}}

          values ->
            property_spec =
              mapping.__property_spec__(property_name) ||
                mapping.__link_spec__(property_name)

            case map_values(values, property_spec.type, property_spec, opts) do
              {:ok, values, additions} ->
                {:cont,
                 {
                   :ok,
                   Description.add(description, {property_iri, values}),
                   if(additions, do: Graph.add(graph, additions), else: graph)
                 }}

              error ->
                {:halt, error}
            end
        end
      end
    )
    |> case do
      {:ok, description, graph} -> {:ok, Graph.add(graph, description)}
      error -> error
    end
  end

  defp map_values(values, {:set, type}, property_spec, opts) when is_list(values) do
    Enum.reduce_while(
      values,
      {:ok, [], Graph.new()},
      fn value, {:ok, mapped, graph} ->
        case map_values(value, type, property_spec, opts) do
          {:ok, mapped_value, nil} ->
            {:cont, {:ok, [mapped_value | mapped], graph}}

          {:ok, mapped_value, additions} ->
            {:cont, {:ok, [mapped_value | mapped], Graph.add(graph, additions)}}

          {:error, _} = error ->
            {:halt, error}
        end
      end
    )
  end

  defp map_values(values, type, _, _) when is_list(values) do
    {:error, TypeError.exception(value: values, type: type)}
  end

  defp map_values(%type{__iri__: iri} = mapping, {:resource, type}, property_spec, opts) do
    with {:ok, graph} <- type.to_rdf(mapping, opts) do
      {:ok, IRI.new(iri), graph}
    end
  end

  defp map_values(values, {_, _} = composite_type, _, _) do
    {:error, TypeError.exception(value: values, type: composite_type)}
  end

  defp map_values(value, nil, _property_spec, _opts) do
    {:ok, Literal.new(value), nil}
  end

  defp map_values(value, XSD.Numeric, _property_spec, _opts) do
    if is_number(value) or match?(%Decimal{}, value) do
      {:ok, Literal.new(value), nil}
    else
      {:error, TypeError.exception(value: value, type: XSD.Numeric)}
    end
  end

  defp map_values(value, type, _property_spec, _opts) do
    {:ok, type.new(value), nil}
  end
end
