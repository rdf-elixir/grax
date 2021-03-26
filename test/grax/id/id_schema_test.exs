defmodule Grax.Id.SchemaTest do
  use Grax.TestCase

  import RDF.Sigils
  alias Grax.Id
  alias Example.{IdSpecs, User, Post}

  describe "generate_id/2" do
    test "success case" do
      assert Id.Schema.generate_id(IdSpecs.GenericIds.expected_id_schema(Post), Example.post()) ==
               {:ok, ~I<http://example.com/posts/lorem-ipsum>}

      assert Id.Schema.generate_id(
               IdSpecs.GenericIds.expected_id_schema(User),
               Example.user(EX.User0)
             ) ==
               {:ok, ~I<http://example.com/users/John%20Doe>}
    end
  end
end
