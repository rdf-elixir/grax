defmodule Grax.Id.Types.UuidTest do
  use Grax.TestCase

  import Grax.UuidTestHelper

  alias Grax.Id
  alias Example.{IdSpecs, User, Post, Comment}

  alias Uniq.UUID

  describe "generic uuid" do
    test "random UUIDs" do
      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.GenericUuids.expected_id_schema(User)
               |> Id.Schema.generate_id(Example.user(EX.User0))

      assert_valid_uuid(id, "http://example.com/", version: 4, format: :hex)

      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.GenericUuids.expected_id_schema(Post)
               |> Id.Schema.generate_id(Example.post())

      assert_valid_uuid(id, "http://example.com/posts/", version: 4, format: :default)

      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.ShortUuids.expected_id_schema(Post)
               |> Id.Schema.generate_id(Example.post())

      assert_valid_uuid(id, "http://example.com/", version: 4, format: :default)

      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.ShortUuids.expected_id_schema(Comment)
               |> Id.Schema.generate_id(%{})

      assert_valid_uuid(id, "http://example.com/comments/", version: 1, format: :hex)
    end

    test "hash-based UUIDs" do
      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.HashUuids.expected_id_schema(User)
               |> Id.Schema.generate_id(Example.user(EX.User0))

      # test that the generated UUIDs are reproducible
      assert {:ok, ^id} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      assert_valid_uuid(id, "http://example.com/", version: 5, format: :default)

      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.HashUuids.expected_id_schema(Post)
               |> Id.Schema.generate_id(Example.post())

      # test that the generated UUIDs are reproducible
      assert {:ok, ^id} =
               IdSpecs.HashUuids.expected_id_schema(Post)
               |> Id.Schema.generate_id(Example.post() |> Map.from_struct())

      assert_valid_uuid(id, "http://example.com/", version: 3, format: :default)

      id =
        RDF.iri(
          "http://example.com/#{UUID.uuid5(:url, Example.user(EX.User0).canonical_email, :hex)}"
        )

      assert {:ok, %RDF.IRI{} = ^id} =
               IdSpecs.ShortUuids.expected_id_schema(User)
               |> Id.Schema.generate_id(Example.user(EX.User0))

      # test that the generated UUIDs are reproducible
      assert {:ok, ^id} =
               IdSpecs.ShortUuids.expected_id_schema(User)
               |> Id.Schema.generate_id(
                 Example.user(EX.User0)
                 |> Map.from_struct()
                 |> Keyword.new()
               )

      assert_valid_uuid(id, "http://example.com/", version: 5, format: :hex)
    end

    test "URN UUIDs" do
      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.UuidUrns.expected_id_schema(User)
               |> Id.Schema.generate_id(Example.user(EX.User0))

      assert_valid_uuid(id, "urn:uuid:", version: 4, format: :urn)

      assert {:ok, %RDF.IRI{} = id} =
               IdSpecs.UuidUrns.expected_id_schema(Post)
               |> Id.Schema.generate_id(Example.post())

      assert_valid_uuid(id, "urn:uuid:", version: 5, format: :urn)
    end

    test "when no value for the name present" do
      assert IdSpecs.ShortUuids.expected_id_schema(User)
             |> Id.Schema.generate_id(name: nil) ==
               {:error, "no value for field :canonical_email for UUID name present"}
    end

    test "with var_mapping" do
      id = RDF.iri("http://example.com/#{UUID.uuid5(:oid, "FOO", :default)}")

      assert {:ok, ^id} =
               Id.Schema.generate_id(
                 IdSpecs.VarMapping.expected_id_schema(Example.VarMappingB),
                 %{name: "foo"}
               )
    end
  end
end
