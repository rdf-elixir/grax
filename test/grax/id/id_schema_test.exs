defmodule Grax.Id.SchemaTest do
  use Grax.TestCase

  import RDF.Sigils
  import Grax.UuidTestHelper

  alias Grax.Id
  alias Example.{IdSpecs, User, Post, Comment}

  describe "generate_id/2" do
    test "based on another field" do
      assert Id.Schema.generate_id(IdSpecs.GenericIds.expected_id_schema(Post), Example.post()) ==
               {:ok, ~I<http://example.com/posts/lorem-ipsum>}

      keyword_list = Example.post() |> Map.from_struct() |> Keyword.new()

      assert Id.Schema.generate_id(IdSpecs.GenericIds.expected_id_schema(Post), keyword_list) ==
               {:ok, ~I<http://example.com/posts/lorem-ipsum>}

      assert Id.Schema.generate_id(
               IdSpecs.GenericIds.expected_id_schema(User),
               Example.user(EX.User0)
             ) ==
               {:ok, ~I<http://example.com/users/John%20Doe>}
    end

    test "random UUID" do
      assert {:ok, id} =
               Id.Schema.generate_id(IdSpecs.ShortUuids.expected_id_schema(Post), Example.post())

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)

      assert {:ok, id} =
               Id.Schema.generate_id(IdSpecs.ShortUuids.expected_id_schema(Comment), %{})

      assert_valid_uuid(id, "http://example.com/comments/", version: 1, type: :hex)
    end

    test "name-based UUID with present name" do
      id =
        RDF.iri(
          "http://example.com/#{UUID.uuid5(:url, Example.user(EX.User0).canonical_email, :hex)}"
        )

      assert {:ok, id} ==
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )
    end
  end
end
