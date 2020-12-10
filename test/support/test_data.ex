defmodule RDF.Mapping.TestData do
  alias RDF.Graph
  alias Example.NS.EX

  @example_user EX.User
                |> EX.name("John Doe")
                |> EX.age(42)
                |> EX.email("jd@example.com", "john@doe.com")
                |> EX.post(EX.Post)

  @example_post EX.Post
                |> EX.title("Lorem ipsum")
                |> EX.content("Lorem ipsum dolor sit amet, …")
                |> EX.author(EX.User)
                |> EX.comment(EX.Comment1, EX.Comment2)

  @example_comments [
    EX.Comment1
    |> EX.content("First")
    |> EX.about(EX.Post)
    |> EX.author(EX.User1),
    EX.Comment2
    |> EX.content("Second")
    |> EX.about(EX.Post)
    |> EX.author(EX.User2)
  ]

  @example_comment_authors [
    EX.User1
    |> EX.name("Erika Mustermann")
    |> EX.email("erika@mustermann.de"),
    EX.User2
    |> EX.name("Max Mustermann")
    |> EX.email("max@mustermann.de")
  ]
  #
  @example_graph Graph.new(
                   [@example_user, @example_post] ++ @example_comments ++ @example_comment_authors
                 )

  def example_description(:user), do: @example_user
  def example_description(:post), do: @example_post
  def example_description(:comment), do: hd(@example_comments)

  def example_graph(content \\ nil)
  def example_graph(nil), do: @example_graph
  def example_graph(content), do: content |> example_description() |> Graph.new()
end
