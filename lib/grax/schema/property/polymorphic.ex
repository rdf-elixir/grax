defmodule Grax.Schema.Property.Polymorphic do
  @moduledoc false

  defstruct [:types]

  alias Grax.Schema.Inheritance
  alias Grax.InvalidResourceTypeError

  def new(class_mapping) do
    {:ok,
     %__MODULE__{
       types:
         Map.new(class_mapping, fn
           {nil, schema} -> {nil, schema}
           {class, schema} -> {RDF.iri(class), schema}
         end)
     }}
  end

  def determine_schema(description, class_mapping, property_schema) do
    types = description[RDF.type()]

    types
    |> List.wrap()
    |> Enum.reduce([], fn class, candidates ->
      case class_mapping[class] do
        nil -> candidates
        schema -> [schema | candidates]
      end
    end)
    |> do_determine_schema(types, class_mapping, property_schema)
  end

  defp do_determine_schema([schema], _, _, _), do: {:ok, schema}

  defp do_determine_schema([], types, class_mapping, property_schema) do
    case class_mapping[nil] do
      nil ->
        case property_schema.on_type_mismatch do
          :ignore ->
            {:ok, nil}

          :error ->
            {:error, InvalidResourceTypeError.exception(type: :no_match, resource_types: types)}
        end

      schema ->
        {:ok, schema}
    end
  end

  defp do_determine_schema(candidates, _, _, _) do
    paths = Enum.flat_map(candidates, &Inheritance.paths/1)

    candidates
    |> Enum.reject(fn candidate -> Enum.any?(paths, &(candidate in &1)) end)
    |> case do
      [result] ->
        {:ok, result}

      [] ->
        raise "Oops, something went fundamentally wrong. Please report this at https://github.com/rdf-elixir/grax/issues"

      remaining ->
        {:error,
         InvalidResourceTypeError.exception(type: :multiple_matches, resource_types: remaining)}
    end
  end
end
