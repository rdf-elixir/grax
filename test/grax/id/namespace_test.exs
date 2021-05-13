defmodule Grax.Id.NamespaceTest do
  use Grax.TestCase

  alias Grax.Id.Namespace

  describe "uri/1" do
    test "root namespace" do
      assert %Namespace{uri: "http://example.com/"} |> Namespace.uri() ==
               "http://example.com/"
    end

    test "nested namespace" do
      assert %Namespace{
               uri: "http://example.com/foo",
               parent: %Namespace{uri: "http://example.com/"}
             }
             |> Namespace.uri() ==
               "http://example.com/foo"
    end
  end
end
