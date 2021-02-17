defmodule Grax.Datatype do
  @moduledoc false

  alias RDF.{IRI, Literal, XSD}

  @builtin_type_mapping Map.new(
                          Literal.Datatype.Registry.builtin_datatypes(),
                          &{&1.name() |> Macro.underscore() |> String.to_atom(), &1}
                        )
                        |> Map.put(:numeric, XSD.Numeric)
                        |> Map.put(:any, nil)

  def builtins, do: @builtin_type_mapping

  def get(:iri), do: {:ok, IRI}

  Enum.each(@builtin_type_mapping, fn {name, type} ->
    def get(unquote(name)), do: {:ok, unquote(type)}
  end)

  def get(type), do: {:error, "unknown type: #{inspect(type)}"}
end
