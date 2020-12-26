defmodule Grax.TestData do
  alias RDF.Graph
  alias Example.NS.EX

  @example_user EX.User0
                |> RDF.type(EX.User, EX.PremiumUser)
                |> EX.name("John Doe")
                |> EX.age(42)
                |> EX.email("jd@example.com", "john@doe.com")
                |> EX.post(EX.Post0)

  @example_post EX.Post0
                |> RDF.type(EX.Post)
                |> EX.title("Lorem ipsum")
                |> EX.content("Lorem ipsum dolor sit amet, …")
                |> EX.author(EX.User0)
                |> EX.comment(EX.Comment1, EX.Comment2)

  @example_comments [
    EX.Comment1
    |> RDF.type(EX.Comment)
    |> EX.content("First")
    |> EX.about(EX.Post0)
    |> EX.author(EX.User1),
    EX.Comment2
    |> RDF.type(EX.Comment)
    |> EX.content("Second")
    |> EX.about(EX.Post0)
    |> EX.author(EX.User2)
  ]

  @example_comment_authors [
    EX.User1
    |> RDF.type(EX.User)
    |> EX.name("Erika Mustermann")
    |> EX.email("erika@mustermann.de"),
    EX.User2
    |> RDF.type(EX.User)
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
