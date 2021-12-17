defmodule Grax.Schema.Struct do
  @moduledoc false

  alias Grax.Schema.{Property, DataProperty, LinkProperty, CustomField, AdditionalStatements}

  @additional_statements_field :__additional_statements__

  def fields(properties, custom_fields, class) do
    [
      {@additional_statements_field, AdditionalStatements.default(class)},
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

  def put_additional_statements(mapping, additional_statements) do
    Map.put(mapping, @additional_statements_field, additional_statements)
  end

  def update_additional_statements(mapping, fun) do
    Map.update!(mapping, @additional_statements_field, fun)
  end
end
