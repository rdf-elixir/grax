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
  @moduledoc false

  alias RDF.Description
  alias RDF.Mapping.Schema.{Type, TypeError}

  import RDF.Utils
  import RDF.Utils.Guards

  @default {:depth, 1}

  def default, do: @default

  def call(mapping_mod, mapping, graph, description, link_specs, opts) do
    graph_load_path = Keyword.get(opts, :__graph_load_path__, [])
    depth = length(graph_load_path)
    graph_load_path = [RDF.iri(mapping.__iri__) | graph_load_path]
    opts = Keyword.put(opts, :__graph_load_path__, graph_load_path)

    Enum.reduce_while(link_specs, {:ok, mapping}, fn {link, link_spec}, {:ok, mapping} ->
      {preload?, next_preload_opt, max_preload_depth} =
        next_preload_opt(
          Keyword.get(opts, :preload),
          Map.get(link_spec, :preload),
          mapping_mod,
          link,
          depth,
          Keyword.get(opts, :__max_preload_depth__)
        )

      if preload? do
        iri = mapping_mod.__property_map__(link)
        objects = Description.get(description, iri)

        cond do
          is_nil(objects) ->
            {:cont,
             {:ok, Map.put(mapping, link, if(Type.set?(link_spec.type), do: [], else: nil))}}

          circle?(objects, graph_load_path) ->
            {:cont, {:ok, mapping}}

          true ->
            opts =
              if next_preload_opt do
                Keyword.put(opts, :preload, next_preload_opt)
              else
                opts
              end
              |> Keyword.put(:__max_preload_depth__, max_preload_depth)

            handle(link, objects, description, graph, link_spec, opts)
            |> case do
              {:ok, mapped_objects} ->
                {:cont, {:ok, Map.put(mapping, link, mapped_objects)}}

              {:error, _} = error ->
                {:halt, error}
            end
        end
      else
        {:cont, {:ok, mapping}}
      end
    end)
  end

  def next_preload_opt(nil, nil, mapping_mod, link, depth, max_depth) do
    next_preload_opt(
      nil,
      mapping_mod.__preload_default__() || @default,
      mapping_mod,
      link,
      depth,
      max_depth
    )
  end

  def next_preload_opt(nil, {:depth, max_depth}, _mapping_mod, _link, 0, _max_depth) do
    {max_depth > 0, nil, max_depth}
  end

  def next_preload_opt(nil, {:depth, _}, _mapping_mod, _link, depth, max_depth) do
    {max_depth - depth > 0, nil, max_depth}
  end

  def next_preload_opt(nil, {:add_depth, add_depth}, _mapping_mod, _link, depth, _max_depth) do
    new_depth = depth + add_depth
    {new_depth - depth > 0, nil, new_depth}
  end

  def next_preload_opt(nil, depth, _mapping_mod, _link, _depth, _max_depth),
    do: raise(ArgumentError, "invalid depth: #{inspect(depth)}")

  def next_preload_opt(preload_opt, preload_spec, mapping_mod, link, depth, parent_max_depth) do
    case preload_opt(link, preload_opt) do
      nil ->
        next_preload_opt(nil, preload_spec, mapping_mod, link, depth, parent_max_depth)

      {:depth, max_depth} = depth_tuple ->
        {max_depth - depth > 0, depth_tuple,
         max_depth(parent_max_depth, preload_spec, mapping_mod, depth)}

      {:add_depth, add_depth} ->
        new_depth = depth + add_depth

        {new_depth - depth > 0, {:depth, new_depth},
         max_depth(new_depth, preload_spec, mapping_mod, depth)}

      property when is_ordinary_atom(property) ->
        {true, property, max_depth(parent_max_depth, preload_spec, mapping_mod, depth)}

      link_preload_opt when is_list(link_preload_opt) ->
        {true, link_preload_opt, max_depth(parent_max_depth, preload_spec, mapping_mod, depth)}
    end
  end

  defp max_depth(_, {:depth, max_depth}, _, 0), do: max_depth
  defp max_depth(_, {:add_depth, add_depth}, _, depth), do: depth + add_depth
  defp max_depth(max_depth, _, _, _) when is_integer(max_depth), do: max_depth

  defp max_depth(nil, nil, mapping_mod, depth),
    do: max_depth(nil, mapping_mod.__preload_default__() || @default, nil, depth)

  @doc false
  def preload_opt(link, opts)

  def preload_opt(link, property) when is_ordinary_atom(property),
    do: preload_opt(link, link == property || nil)

  def preload_opt(link, opts) when is_list(opts) do
    cond do
      Keyword.keyword?(opts) ->
        case Keyword.get(opts, link) do
          nil -> nil
          link_preload_opt when is_list(link_preload_opt) -> link_preload_opt
          property when is_ordinary_atom(property) -> property
          preload_opt -> normalize_spec(preload_opt) |> relative_depth()
        end

      link in opts ->
        preload_opt(link, true)

      true ->
        nil
    end
  end

  def preload_opt(_link, opts), do: normalize_spec(opts)

  defp relative_depth({depth_type, depth}, offset \\ 1), do: {depth_type, offset + depth}

  @doc false
  def normalize_spec(preload_value, spec_semantics \\ false)
  def normalize_spec(nil, _), do: nil
  def normalize_spec(true, false), do: {:add_depth, 1}
  def normalize_spec(false, false), do: {:add_depth, 0}
  def normalize_spec(integer, false) when is_integer(integer), do: {:add_depth, integer}
  def normalize_spec(true, true), do: {:depth, 1}
  def normalize_spec(false, true), do: {:depth, 0}
  def normalize_spec(integer, true) when is_integer(integer), do: {:depth, integer}

  def normalize_spec({:+, _line, [integer]}, true) when is_integer(integer),
    do: {:add_depth, integer}

  def normalize_spec({keyword, _} = depth, _) when keyword in [:depth, :add_depth],
    do: depth

  def normalize_spec(invalid, _),
    do: raise(ArgumentError, "invalid depth specification: #{inspect(invalid)}")

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
