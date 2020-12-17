defmodule RDF.Mapping.ToRDF do
  @moduledoc false

  alias RDF.{IRI, BlankNode, Literal, XSD, Graph, Description}
  alias RDF.Mapping.{Link, Validation}
  alias RDF.Mapping.Schema.TypeError

  def call(%mapping_mod{} = struct, opts) do
    with {:ok, struct} <- Validation.call(struct, opts) do
      mapping_mod.__property_map__()
      |> Enum.reduce_while(
        {:ok, Description.new(struct.__id__), Graph.new()},
        fn {property_name, property_iri}, {:ok, description, graph} ->
          case Map.get(struct, property_name) do
            nil ->
              {:cont, {:ok, description, graph}}

            [] ->
              {:cont, {:ok, description, graph}}

            %Link.NotLoaded{} ->
              {:cont, {:ok, description, graph}}

            values ->
              property_spec =
                mapping_mod.__property_spec__(property_name) ||
                  mapping_mod.__link_spec__(property_name)

              case map_values(values, property_spec.type, property_spec, opts) do
                {:ok, values, additions} ->
                  {:cont, add_statements(graph, description, property_iri, values, additions)}

                error ->
                  {:halt, error}
              end
          end
        end
      )
      |> case do
        {:ok, description, graph} ->
          description =
            if class = mapping_mod.__class__() do
              description |> RDF.type(RDF.iri(class))
            else
              description
            end

          {:ok, Graph.add(graph, description)}

        error ->
          error
      end
    end
  end

  defp add_statements(graph, description, {:inverse, property}, values, additions) do
    {
      :ok,
      description,
      if(additions, do: Graph.add(graph, additions), else: graph)
      |> Graph.add(
        Enum.map(values, fn value ->
          {value, property, description.subject}
        end)
      )
    }
  end

  defp add_statements(graph, description, property, values, additions) do
    {
      :ok,
      Description.add(description, {property, values}),
      if(additions, do: Graph.add(graph, additions), else: graph)
    }
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

  defp map_values(%type{__id__: id} = mapping, {:resource, type}, property_spec, opts) do
    with {:ok, graph} <- RDF.Mapping.to_rdf(mapping, opts) do
      {:ok, id, graph}
    end
  end

  defp map_values(%IRI{} = iri, _, _, _), do: {:ok, iri, nil}
  defp map_values(%BlankNode{} = bnode, nil, _, _), do: {:ok, bnode, nil}
  defp map_values(value, nil, _, _), do: {:ok, Literal.new(value), nil}
  defp map_values(value, XSD.Numeric, _, _), do: {:ok, Literal.new(value), nil}
  defp map_values(value, type, _, _), do: {:ok, type.new(value), nil}
end
