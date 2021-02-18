defmodule Grax.Schema.Type do
  defmodule Constructors do
    @moduledoc !"""
               These are type constructor functions available in a Grax schema block.
               """

    def list(opts \\ []), do: list_of(nil, opts)

    def list_of(type, opts \\ []) do
      cond do
        card = Keyword.get(opts, :card) -> {:list_set, type, cardinality(card)}
        min = Keyword.get(opts, :min) -> {:list_set, type, min_cardinality(min)}
        true -> {:list_set, type, nil}
      end
    end

    defp cardinality(%Range{} = range) do
      cond do
        range.first == range.last -> range.first
        range.first > range.last -> range.last..range.first
        true -> range
      end
    end

    defp cardinality(number) when is_integer(number) and number >= 0, do: number
    defp cardinality(invalid), do: raise("invalid cardinality: #{inspect(invalid)}")

    defp min_cardinality(0), do: nil
    defp min_cardinality(number) when is_integer(number) and number >= 0, do: {:min, number}
    defp min_cardinality(invalid), do: raise("invalid min cardinality: #{inspect(invalid)}")
  end

  def set?({:list_set, _}), do: true
  def set?(_), do: false
end
