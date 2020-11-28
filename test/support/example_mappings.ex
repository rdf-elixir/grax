defmodule Example do
  alias Example.NS.EX

  defmodule User do
    use RDF.Mapping

    schema do
      property :name, EX.name(), type: :string
      property :age, EX.age(), type: :integer
    end
  end

  defmodule Untyped do
    use RDF.Mapping

    schema do
      property :foo, EX.foo()
    end
  end

  defmodule Types do
    use RDF.Mapping

    schema do
      RDF.Mapping.Schema.Type.builtins()
      |> Enum.each(fn {type, _} ->
        property type, apply(EX, type, []), type: type
      end)
    end
  end
end
