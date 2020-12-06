defmodule RDF.Mapping.TestData do
  alias RDF.Graph
  alias Example.NS.EX

  import RDF.Sigils

  @example_user EX.User
                |> EX.name("John Doe")
                |> EX.age(42)
                |> EX.email("jd@example.com", "john@doe.com")
                |> EX.post(EX.Post)

  @example_post EX.Post
                |> EX.title("Lorem ipsum")
                |> EX.content("Lorem ipsum dolor sit amet, …")
                |> EX.author(EX.User)

  @example_graph Graph.new([@example_user, @example_post])

  def example_description(:user), do: @example_user
  def example_description(:post), do: @example_post

  def example_graph(content \\ nil)
  def example_graph(nil), do: @example_graph
  def example_graph(content), do: content |> example_description() |> Graph.new()
end
