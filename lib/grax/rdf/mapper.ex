defmodule Grax.RDF.Mapper do
  @moduledoc false

  alias RDF.{IRI, BlankNode, Literal, XSD, Graph, Description}
  alias Grax.{Link, Validator}
  alias Grax.Schema.TypeError

  def call(%mapping_mod{} = mapping, opts) do
    with {:ok, mapping} <- Validator.call(mapping, opts) do
      mapping_mod.__properties__()
      |> Enum.reduce_while(
        {:ok, Description.new(mapping.__id__), Graph.new()},
        fn {property_name, property_schema}, {:ok, description, graph} ->
          case Map.get(mapping, property_name) do
            nil ->
              {:cont, {:ok, description, graph}}

            [] ->
              {:cont, {:ok, description, graph}}

            %Link.NotLoaded{} ->
              {:cont, {:ok, description, graph}}

            values ->
              case handle(values, mapping, property_schema, opts) do
                {:ok, values, additions} ->
                  {:cont,
                   add_statements(graph, description, property_schema.iri, values, additions)}

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

  defp handle(values, mapping, %{to_rdf: to_rdf} = property_schema, _opts)
       when not is_nil(to_rdf) do
    case apply(property_schema.mapping, to_rdf, [values, mapping]) do
      {:ok, values} -> {:ok, values, nil}
      pass_through -> pass_through
    end
  end

  defp handle(values, _, property_schema, opts) do
    map_values(values, property_schema.type, property_schema, opts)
  end

  defp map_values(values, {:set, type}, property_schema, opts) when is_list(values) do
    Enum.reduce_while(
      values,
      {:ok, [], Graph.new()},
      fn value, {:ok, mapped, graph} ->
        case map_values(value, type, property_schema, opts) do
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

  defp map_values(%type{__id__: id} = mapping, {:resource, type}, _property_schema, opts) do
    with {:ok, graph} <- Grax.to_rdf(mapping, opts) do
      {:ok, id, graph}
    end
  end

  defp map_values(%IRI{} = iri, _, _, _), do: {:ok, iri, nil}
  defp map_values(%BlankNode{} = bnode, nil, _, _), do: {:ok, bnode, nil}
  defp map_values(value, nil, _, _), do: {:ok, Literal.new(value), nil}
  defp map_values(value, XSD.Numeric, _, _), do: {:ok, Literal.new(value), nil}
  defp map_values(value, type, _, _), do: {:ok, type.new(value), nil}
end
