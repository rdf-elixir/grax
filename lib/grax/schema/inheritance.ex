defmodule Grax.Schema.Inheritance do
  @moduledoc false

  def paths(schema) do
    if super_classes = schema.__super__() do
      Enum.flat_map(super_classes, fn super_class ->
        case paths(super_class) do
          [] -> [[super_class]]
          paths -> Enum.map(paths, &[super_class | &1])
        end
      end)
    else
      []
    end
  end

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
end
