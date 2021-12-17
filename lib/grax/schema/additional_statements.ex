defmodule Grax.Schema.AdditionalStatements do
  @moduledoc false

  alias RDF.Statement

  @default %{}
  def default, do: @default

  def add(additional_statements, predications) do
    Enum.reduce(predications, additional_statements, fn
      {predicate, objects}, additional_statements ->
        coerced_objects = normalize_objects(objects)

        Map.update(
          additional_statements,
          Statement.coerce_predicate(predicate),
          coerced_objects,
          &MapSet.union(&1, coerced_objects)
        )
    end)
  end

  def put(additional_statements, predications) do
    Enum.reduce(predications, additional_statements, fn
      {predicate, nil}, additional_statements ->
        Map.delete(additional_statements, Statement.coerce_predicate(predicate))

      {predicate, objects}, additional_statements ->
        Map.put(
          additional_statements,
          Statement.coerce_predicate(predicate),
          normalize_objects(objects)
        )
    end)
  end

  defp normalize_objects(objects) do
    objects
    |> List.wrap()
    |> Enum.map(&Statement.coerce_object/1)
    |> MapSet.new()
  end
end
