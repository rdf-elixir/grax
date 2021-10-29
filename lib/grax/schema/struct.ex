defmodule Grax.Schema.Struct do
  @moduledoc false

  alias Grax.Schema.{Property, DataProperty, LinkProperty, CustomField}

  def fields(properties, custom_fields) do
    [
      {:__additional_statements__, %{}},
      :__id__
      | property_fields(properties) ++ custom_fields(custom_fields)
    ]
  end

  defp property_fields(properties) do
    Enum.map(properties, fn
      {name, %DataProperty{default: default}} -> {name, default}
      {name, %LinkProperty{type: type}} -> {name, Property.default(type)}
    end)
  end

  defp custom_fields(fields) do
    Enum.map(fields, fn
      {name, %CustomField{default: default}} -> {name, default}
    end)
  end
end
