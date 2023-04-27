defmodule Grax.Schema.Mapping do
  @moduledoc false

  def from(value, to_schema) do
    if Grax.Schema.struct?(value) do
      with {:ok, graph} <- Grax.to_rdf(value),
           {:ok, mapped} <- to_schema.load(graph, value.__id__) do
        Grax.put(mapped, extracted_field_values(value, to_schema))
      end
    else
      {:error, "invalid value #{inspect(value)}; only Grax.Schema structs are supported"}
    end
  end

  def from!(value, to_schema) do
    case from(value, to_schema) do
      {:ok, struct} -> struct
      {:error, error} -> raise error
    end
  end

  defp extracted_field_values(%from_schema{} = from, to_schema) do
    from_fields = Map.keys(from_schema.__custom_fields__())

    Enum.flat_map(to_schema.__custom_fields__(), fn {field, _} ->
      if field in from_fields do
        [{field, Map.get(from, field)}]
      else
        []
      end
    end)
  end
end
