defmodule RDF.Mapping.TestData do
  alias RDF.Graph
  alias Example.NS.EX

  import RDF.Sigils

  @example_graph EX.User
                 |> EX.name("John Doe")
                 |> Graph.new()

  def example_graph, do: @example_graph
end
