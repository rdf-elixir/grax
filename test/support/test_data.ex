defmodule RDF.Mapping.TestData do
  alias RDF.Graph
  alias Example.NS.EX

  import RDF.Sigils

  @example_description EX.User
                       |> EX.name("John Doe")
                       |> EX.age(42)
                       |> EX.email("jd@example.com", "john@doe.com")

  @example_graph Graph.new(@example_description)

  def example_description, do: @example_description
  def example_graph, do: @example_graph
end
