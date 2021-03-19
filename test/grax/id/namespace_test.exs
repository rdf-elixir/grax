defmodule Grax.Id.NamespaceTest do
  use Grax.TestCase

  alias Grax.Id.Namespace
  import RDF.Sigils

  describe "uri/1" do
    test "root namespace" do
      assert %Namespace{segment: "http://example.com/"}
             |> Namespace.uri() ==
               "http://example.com/"
    end

    test "nested namespace" do
      assert %Namespace{segment: "foo", parent: %Namespace{segment: "http://example.com/"}}
             |> Namespace.uri() ==
               "http://example.com/foo"
    end
  end

  test "iri/1" do
    assert %Namespace{segment: "foo", parent: %Namespace{segment: "http://example.com/"}}
           |> Namespace.iri() == ~I<http://example.com/foo>
  end
end
