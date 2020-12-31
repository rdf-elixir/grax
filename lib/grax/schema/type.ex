defmodule Grax.Schema.Type do
  @moduledoc false

  alias RDF.{IRI, Literal, XSD}

  @builtin_type_mapping Map.new(
                          Literal.Datatype.Registry.builtin_datatypes(),
                          &{&1.name() |> Macro.underscore() |> String.to_atom(), &1}
                        )
                        |> Map.put(:numeric, XSD.Numeric)
                        |> Map.put(:any, nil)

  def builtins, do: @builtin_type_mapping

  def get(type)

  def get(:iri), do: {:ok, IRI}

  def get([type]) do
    with {:ok, inner_type} <- get(type) do
      {:ok, {:set, inner_type}}
    end
  end

  def get([]), do: get([:any])

  Enum.each(@builtin_type_mapping, fn {name, type} ->
    def get(unquote(name)), do: {:ok, unquote(type)}
  end)
end
