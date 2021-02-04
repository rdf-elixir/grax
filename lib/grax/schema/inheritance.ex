defmodule Grax.Schema.Inheritance do
  @moduledoc false

  def inherit_properties(_, nil, properties), do: properties

  def inherit_properties(child_schema, parent_schema, properties) do
    parent_schema.__properties__()
    |> Map.new(fn {name, property_schema} ->
      {name, %{property_schema | schema: child_schema}}
    end)
    |> Map.merge(properties)
  end

  def inherit_custom_fields(_, nil, custom_fields), do: custom_fields

  def inherit_custom_fields(_child_schema, parent_schema, custom_fields) do
    parent_schema.__custom_fields__() |> Map.merge(custom_fields)
  end
end
