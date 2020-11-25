defmodule RDF.Mapping.ToRDFTest do
  use RDF.Test.Case

  test "successful mapping" do
    assert %Example.User{
             __iri__: IRI.to_string(EX.User),
             name: "John Doe"
           }
           |> Example.User.to_rdf() == {:ok, example_graph()}
  end
end
