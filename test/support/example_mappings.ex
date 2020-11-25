defmodule Example do
  alias Example.NS.EX

  defmodule User do
    use RDF.Mapping

    schema do
      property :name, EX.name()
    end
  end
end
