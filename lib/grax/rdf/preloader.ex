defmodule Grax.RDF.Preloader do
  @moduledoc false

  alias Grax.RDF.Loader
  import Grax.RDF.Access
  import RDF.Guards

  defmodule Error do
    defexception [:message]
  end

  @default {:depth, 1}

  def default, do: @default

  def call(schema, mapping, graph, opts) do
    call(schema, mapping, graph, description(graph, mapping.__id__), opts)
  end

  def call(schema, mapping, graph, description, opts) do
    graph_load_path = Keyword.get(opts, :__graph_load_path__, [])
    depth = length(graph_load_path)
    graph_load_path = [mapping.__id__ | graph_load_path]
    opts = Keyword.put(opts, :__graph_load_path__, graph_load_path)
    link_schemas = schema.__properties__(:link)

    Enum.reduce_while(link_schemas, {:ok, mapping}, fn {link, link_schema}, {:ok, mapping} ->
      {preload?, next_preload_opt, max_preload_depth} =
        next_preload_opt(
          Keyword.get(opts, :preload),
          link_schema.preload,
          schema,
          link,
          depth,
          Keyword.get(opts, :__max_preload_depth__)
        )

      if preload? do
        objects = objects(graph, description, link_schema.iri)

        cond do
          is_nil(objects) ->
            {:cont, {:ok, mapping}}

          # The circle check is not needed when preload opts are given as their finite depth
          # overwrites any additive preload depths of properties which may cause infinite preloads
          is_nil(next_preload_opt) and circle?(objects, graph_load_path) ->
            Loader.add_objects(mapping, link, objects, description, graph, link_schema)

          true ->
            opts =
              if next_preload_opt do
                Keyword.put(opts, :preload, next_preload_opt)
              else
                opts
              end
              |> Keyword.put(:__max_preload_depth__, max_preload_depth)

            handle(link, objects, description, graph, link_schema, opts)
            |> case do
              {:ok, mapped_objects} ->
                {:cont, {:ok, Map.put(mapping, link, mapped_objects)}}

              {:error, _} = error ->
                {:halt, error}
            end
        end
      else
        Loader.load_properties([{link, link_schema}], mapping, graph, description)
        |> case do
          {:ok, _} = ok_mapping -> {:cont, ok_mapping}
          {:error, _} = error -> {:balt, error}
        end
      end
    end)
  end

  def next_preload_opt(nil, nil, schema, link, depth, max_depth) do
    next_preload_opt(
      nil,
      schema.__preload_default__() || @default,
      schema,
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

  def next_preload_opt(
        {:depth, max_depth} = depth_tuple,
        preload_spec,
        schema,
        _link,
        depth,
        parent_max_depth
      ) do
    {max_depth - depth > 0, depth_tuple, max_depth(parent_max_depth, preload_spec, schema, depth)}
  end

  def next_preload_opt({:add_depth, add_depth}, preload_spec, schema, _, depth, _) do
    new_depth = depth + add_depth

    {new_depth - depth > 0, {:depth, new_depth},
     max_depth(new_depth, preload_spec, schema, depth)}
  end

  defp max_depth(_, {:depth, max_depth}, _, 0), do: max_depth
  defp max_depth(_, {:add_depth, add_depth}, _, depth), do: depth + add_depth
  defp max_depth(max_depth, _, _, _) when is_integer(max_depth), do: max_depth

  defp max_depth(nil, nil, schema, depth),
    do: max_depth(nil, schema.__preload_default__() || @default, nil, depth)

  defp circle?(objects, graph_load_path) do
    Enum.any?(objects, &(&1 in graph_load_path))
  end

  defp handle(property, objects, description, graph, property_schema, opts)

  defp handle(_property, objects, _description, graph, property_schema, opts) do
    map_links(objects, property_schema.type, property_schema, graph, opts)
  end

  defp map_links(values, {:list_set, type}, property_schema, graph, opts) do
    with {:ok, mapped} <- map_links(values, type, property_schema, graph, opts) do
      {:ok, List.wrap(mapped)}
    end
  end

  defp map_links([value], type, property_schema, graph, opts) do
    map_link(value, type, property_schema, graph, opts)
  end

  defp map_links(values, type, property_schema, graph, opts) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, mapped} ->
      case map_link(value, type, property_schema, graph, opts) do
        {:ok, nil} -> {:cont, {:ok, mapped}}
        {:ok, mapping} -> {:cont, {:ok, [mapping | mapped]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, []} -> {:ok, nil}
      {:ok, [mapped]} -> {:ok, mapped}
      {:ok, mapped} -> {:ok, Enum.reverse(mapped)}
      error -> error
    end
  end

  defp map_link(resource, _, property_schema, _graph, _opts)
       when not is_rdf_resource(resource) do
    {:error,
     Error.exception(
       "unable to preload #{inspect(property_schema.name)} of #{inspect(property_schema.schema)} from value #{inspect(resource)}"
     )}
  end

  defp map_link(resource, {:resource, class_mapping}, property_schema, graph, opts)
       when is_map(class_mapping) do
    description = description(graph, resource)

    with {:ok, schema} when not is_nil(schema) <-
           determine_schema(
             description[RDF.type()],
             class_mapping,
             property_schema.on_type_mismatch
           ) do
      schema.load(graph, resource, Keyword.put(opts, :description, description))
    end
  end

  defp map_link(resource, {:resource, schema}, _property_schema, graph, opts) do
    schema.load(graph, resource, opts)
  end
end
