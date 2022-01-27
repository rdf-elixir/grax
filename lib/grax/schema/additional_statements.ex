defmodule Grax.Schema.AdditionalStatements do
  @moduledoc false

  alias RDF.Statement

  @empty %{}
  def empty, do: @empty

  def default(nil), do: @empty
  def default(class), do: add(@empty, %{RDF.type() => class})

  def add(additional_statements, predications) do
    Enum.reduce(predications, additional_statements, fn
      {predicate, objects}, additional_statements ->
        add(additional_statements, predicate, objects)
    end)
  end

  def add(additional_statements, predicate, objects) do
    coerced_objects = normalize_objects(objects)

    Map.update(
      additional_statements,
      Statement.coerce_predicate(predicate),
      coerced_objects,
      &MapSet.union(&1, coerced_objects)
    )
  end

  def put(additional_statements, predications) do
    Enum.reduce(predications, additional_statements, fn
      {predicate, objects}, additional_statements ->
        put(additional_statements, predicate, objects)
    end)
  end

  def put(additional_statements, predicate, nil) do
    Map.delete(additional_statements, Statement.coerce_predicate(predicate))
  end

  def put(additional_statements, predicate, objects) do
    Map.put(
      additional_statements,
      Statement.coerce_predicate(predicate),
      normalize_objects(objects)
    )
  end

  defp normalize_objects(objects) do
    objects
    |> List.wrap()
    |> Enum.map(&Statement.coerce_object/1)
    |> MapSet.new()
  end

  def statements(additional_statements, subject) do
    RDF.description(subject,
      init: Map.new(additional_statements, fn {p, os} -> {p, MapSet.to_list(os)} end)
    )
  end
end
