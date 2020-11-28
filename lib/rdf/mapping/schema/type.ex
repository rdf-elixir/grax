defmodule RDF.Mapping.Schema.Type do
  alias RDF.Literal

  @builtin_type_mapping Map.new(
                          Literal.Datatype.Registry.builtin_datatypes(),
                          &{&1.name() |> Macro.underscore() |> String.to_atom(), &1}
                        )
                        |> Map.put(:any, nil)

  def builtins, do: @builtin_type_mapping

  def get(type)

  Enum.each(@builtin_type_mapping, fn {name, type} ->
    def get(unquote(name)), do: {:ok, unquote(type)}
  end)
end
