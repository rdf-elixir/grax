defmodule RDF.Mapping.Link.NotLoaded do
  @moduledoc """
  Struct returned by links when they are not loaded.

  The fields are:

    * `__field__` - the link field in `owner`
    * `__owner__` - the schema that owns the link
  """

  @type t :: %__MODULE__{
          __field__: atom(),
          __owner__: any()
        }

  defstruct [:__field__, :__owner__]

  defimpl Inspect do
    def inspect(not_loaded, _opts) do
      msg = "link #{inspect(not_loaded.__field__)} is not loaded"
      ~s(#RDF.Mapping.Link.NotLoaded<#{msg}>)
    end
  end
end

defmodule RDF.Mapping.Link.Preloader do
  alias RDF.Description
  alias RDF.Mapping.Schema.{Type, TypeError}

  import RDF.Utils

  def call(mapping_mod, mapping, graph, description, link_specs, opts) do
    graph_load_path = [RDF.iri(mapping.__iri__) | Keyword.get(opts, :__graph_load_path__, [])]
    depth = length(graph_load_path)
    opts = Keyword.put(opts, :__graph_load_path__, graph_load_path)

    link_specs
    |> Enum.filter(&preload?(&1, depth, opts))
    |> Enum.reduce_while({:ok, mapping}, fn {link, link_spec}, {:ok, mapping} ->
      iri = mapping_mod.__property_map__(link)
      objects = Description.get(description, iri)

      cond do
        is_nil(objects) ->
          {:cont, {:ok, Map.put(mapping, link, if(Type.set?(link_spec.type), do: [], else: nil))}}

        circle?(objects, graph_load_path) ->
          {:cont, {:ok, mapping}}

        true ->
          handle(link, objects, description, graph, link_spec, opts)
          |> case do
            {:ok, mapped_objects} ->
              {:cont, {:ok, Map.put(mapping, link, mapped_objects)}}

            {:error, _} = error ->
              {:halt, error}
          end
      end
    end)
  end

  @default {:depth, 1}

  defp preload?({_link, link_spec}, depth, opts) do
    case Map.get(link_spec, :preload, @default) do
      preload when is_boolean(preload) -> preload
      {:depth, max_depth} -> depth <= max_depth
    end
  end

  defp circle?(objects, graph_load_path) do
    Enum.any?(objects, &(&1 in graph_load_path))
  end

  defp handle(property, objects, description, graph, property_spec, opts)

  defp handle(_property, objects, _description, graph, property_spec, opts) do
    map_links(objects, property_spec.type, property_spec, graph, opts)
  end

  defp map_links(values, {:set, type}, property_spec, graph, opts) do
    map_while_ok(values, &map_link(&1, type, property_spec, graph, opts))
  end

  defp map_links([value], type, property_spec, graph, opts) do
    map_link(value, type, property_spec, graph, opts)
  end

  defp map_links(values, type, _, _, _) do
    {:error, TypeError.exception(value: values, type: type)}
  end

  defp map_link(resource, {:resource, module}, property_spec, graph, opts) do
    module.from_rdf(graph, resource, opts)
  end
end
