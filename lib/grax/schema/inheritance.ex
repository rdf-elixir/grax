defmodule Grax.Schema.Inheritance do
  @moduledoc false

  alias Grax.Schema.Registry
  alias Grax.InvalidResourceTypeError

  def inherit_properties(_, nil, properties), do: properties

  def inherit_properties(child_schema, parent_schema, properties) do
    parent_schema
    |> inherited_properties(Map.keys(properties))
    |> Map.new(fn {name, property_schema} -> {name, %{property_schema | schema: child_schema}} end)
    |> Map.merge(properties)
  end

  defp inherited_properties([parent_schema], _) do
    parent_schema.__properties__()
  end

  defp inherited_properties(parent_schemas, child_properties) do
    Enum.reduce(parent_schemas, %{}, fn parent_schema, properties ->
      Map.merge(properties, Map.drop(parent_schema.__properties__(), child_properties), fn
        _, property1, property2 ->
          if Map.put(property1, :schema, nil) == Map.put(property2, :schema, nil) do
            property1
          else
            raise """
            conflicting definitions in inherited property #{property1.name}:
            #{inspect(property1)} vs.
            #{inspect(property2)}
            """
          end
      end)
    end)
  end

  def inherit_custom_fields(_, nil, custom_fields), do: custom_fields

  def inherit_custom_fields(_child_schema, parent_schema, custom_fields) do
    parent_schema
    |> inherited_custom_fields(Map.keys(custom_fields))
    |> Map.merge(custom_fields)
  end

  defp inherited_custom_fields([parent_schema], _) do
    parent_schema.__custom_fields__()
  end

  defp inherited_custom_fields(parent_schemas, child_fields) do
    Enum.reduce(parent_schemas, %{}, fn parent_schema, custom_fields ->
      Map.merge(custom_fields, Map.drop(parent_schema.__custom_fields__(), child_fields), fn
        _, custom_field1, custom_field2 ->
          if custom_field1 == custom_field2 do
            custom_field1
          else
            raise """
            conflicting definitions in inherited custom field #{custom_field1.name}:
            #{inspect(custom_field1)} vs.
            #{inspect(custom_field2)}
            """
          end
      end)
    end)
  end

  def determine_schema(schema, description, property_schema) do
    types = RDF.Description.get(description, RDF.type(), [])

    types
    |> Enum.flat_map(&(&1 |> Registry.schema() |> List.wrap()))
    |> Enum.filter(&inherited_schema?(&1, schema))
    |> case do
      [result_schema] ->
        {:ok, result_schema}

      [] ->
        case property_schema.on_type_mismatch do
          :ignore ->
            {:ok, schema}

          :error ->
            {:error, InvalidResourceTypeError.exception(type: :no_match, resource_types: types)}
        end

      multiple ->
        paths = Enum.flat_map(multiple, &paths_to(&1, schema))

        multiple
        |> Enum.reject(fn candidate -> Enum.any?(paths, &(candidate in &1)) end)
        |> case do
          [result] ->
            {:ok, result}

          [] ->
            raise "Oops, something went fundamentally wrong. Please report this at https://github.com/rdf-elixir/grax/issues"

          remaining ->
            {:error,
             InvalidResourceTypeError.exception(
               type: :multiple_matches,
               resource_types: remaining
             )}
        end
    end
  end

  def inherited_schema?(schema, root)
  def inherited_schema?(schema, schema), do: true
  def inherited_schema?(nil, _), do: false

  def inherited_schema?(schemas, root_schema) when is_list(schemas) do
    Enum.any?(schemas, &inherited_schema?(&1, root_schema))
  end

  def inherited_schema?(schema, root_schema) do
    inherited_schema?(schema.__super__(), root_schema)
  end

  def paths(schema) do
    if parent_schemas = schema.__super__() do
      Enum.flat_map(parent_schemas, fn parent_schema ->
        case paths(parent_schema) do
          [] -> [[parent_schema]]
          paths -> Enum.map(paths, &[parent_schema | &1])
        end
      end)
    else
      []
    end
  end

  def paths_to(root, root), do: []

  def paths_to(schema, root) do
    parent_schemas = schema.__super__()

    cond do
      parent_schemas ->
        Enum.flat_map(parent_schemas, fn parent_schema ->
          case paths_to(parent_schema, root) do
            nil -> []
            [] -> [[parent_schema]]
            paths -> Enum.map(paths, &[parent_schema | &1])
          end
        end)

      schema != root ->
        nil

      true ->
        []
    end
  end
end
