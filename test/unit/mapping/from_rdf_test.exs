defmodule RDF.Mapping.FromRDFTest do
  use RDF.Test.Case

  test "successful mapping from a graph" do
    assert Example.User.from_rdf(example_graph(), EX.User) ==
             {:ok,
              %Example.User{
                __iri__: IRI.to_string(EX.User),
                name: "John Doe"
                #                  email: ~w[bar1 bar2]
              }}
  end

  test "successful mapping from a description" do
    assert Example.User.from_rdf(example_description(), EX.User) ==
             {:ok,
              %Example.User{
                __iri__: IRI.to_string(EX.User),
                name: "John Doe"
              }}
  end

  test "with non-RDF.Data" do
    assert_raise ArgumentError, "invalid input data: %{}", fn ->
      Example.User.from_rdf(%{}, EX.User)
    end
  end

  test "when no description for the given IRI exists in the graph" do
    assert Example.User.from_rdf(example_graph(), EX.not_existing()) ==
             {:error, "No description of #{inspect(EX.not_existing())} found."}
  end
end
