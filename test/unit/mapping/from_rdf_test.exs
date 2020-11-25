defmodule RDF.Mapping.FromRDFTest do
  use RDF.Test.Case

  test "successful mapping" do
    assert Example.User.from_rdf(example_graph(), EX.User) ==
             {:ok,
              %Example.User{
                __iri__: IRI.to_string(EX.User),
                name: "John Doe"
                #                  email: ~w[bar1 bar2]
              }}
  end

  test "when no description for the given IRI exists in the graph" do
    assert Example.User.from_rdf(example_graph(), EX.not_existing()) ==
             {:error, "No description of #{inspect(EX.not_existing())} found."}
  end
end
