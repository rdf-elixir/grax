defmodule Grax.Schema.LinkProperty.Union do
  @moduledoc false

  defstruct [:types]

  alias Grax.Schema.Inheritance
  alias Grax.InvalidResourceTypeError
  alias RDF.Description

  def new(class_mapping) do
    {:ok, %__MODULE__{types: normalize_class_mapping(class_mapping)}}
  end

  defp normalize_class_mapping(class_mapping) do
    Map.new(class_mapping, fn
      {nil, schema} ->
        {nil, schema}

      {class, schema} ->
        {RDF.iri(class), schema}

      schema when is_atom(schema) ->
        cond do
          not Grax.Schema.schema?(schema) ->
            raise "invalid union type definition: #{inspect(schema)}"

          class = schema.__class__() ->
            {RDF.iri(class), schema}

          true ->
            raise "invalid union type definition: #{inspect(schema)} does not specify a class"
        end

      invalid ->
        raise "invalid union type definition: #{inspect(invalid)}"
    end)
  end

  def determine_schema(%Description{} = description, class_mapping, property_schema) do
    description
    |> Description.get(RDF.type(), [])
    |> determine_schema(class_mapping, property_schema)
  end

  def determine_schema(types, class_mapping, property_schema) do
    types
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
    type_mismatch(class_mapping[nil], property_schema.on_type_mismatch, types)
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

  defp type_mismatch(fallback_schema, on_type_mismatch, types)
  defp type_mismatch(nil, :ignore, _), do: {:ok, nil}

  defp type_mismatch(nil, :error, types),
    do: {:error, InvalidResourceTypeError.exception(type: :no_match, resource_types: types)}

  defp type_mismatch(fallback, _, _), do: {:ok, fallback}
end
