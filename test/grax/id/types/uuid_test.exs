defmodule Grax.Id.Types.UuidTest do
  use Grax.TestCase

  import Grax.UuidTestHelper

  alias Grax.Id
  alias Example.{IdSpecs, User, Post, Comment}

  describe "generic uuid macro" do
    test "random UUIDs" do
      assert {:ok, %RDF.IRI{} = id} =
               Id.Schema.generate_id(
                 IdSpecs.GenericUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :hex)

      assert {:ok, %RDF.IRI{} = id} =
               Id.Schema.generate_id(
                 IdSpecs.GenericUuids.expected_id_schema(Post),
                 Example.post()
               )

      assert_valid_uuid(id, "http://example.com/posts/", version: 4, type: :default)

      assert {:ok, %RDF.IRI{} = id} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(Post),
                 Example.post()
               )

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)

      assert {:ok, %RDF.IRI{} = id} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(Comment),
                 %{}
               )

      assert_valid_uuid(id, "http://example.com/comments/", version: 1, type: :hex)
    end

    test "hash-based UUIDs" do
      assert {:ok, %RDF.IRI{} = id} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      # test that the generated UUIDs are reproducible
      assert {:ok, ^id} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      assert_valid_uuid(id, "http://example.com/", version: 5, type: :default)

      assert {:ok, %RDF.IRI{} = id} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(Post),
                 Example.post()
               )

      # test that the generated UUIDs are reproducible
      assert {:ok, ^id} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(Post),
                 Example.post() |> Map.from_struct()
               )

      assert_valid_uuid(id, "http://example.com/", version: 3, type: :default)

      id =
        RDF.iri(
          "http://example.com/#{UUID.uuid5(:url, Example.user(EX.User0).canonical_email, :hex)}"
        )

      assert {:ok, %RDF.IRI{} = ^id} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      # test that the generated UUIDs are reproducible
      assert {:ok, ^id} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(User),
                 Example.user(EX.User0) |> Map.from_struct() |> Keyword.new()
               )

      assert_valid_uuid(id, "http://example.com/", version: 5, type: :hex)
    end

    test "with var_proc" do
      id = RDF.iri("http://example.com/#{UUID.uuid5(:oid, "FOO", :default)}")

      assert {:ok, ^id} =
               Id.Schema.generate_id(IdSpecs.VarProc.expected_id_schema(Example.VarProcB), %{
                 name: "foo"
               })
    end
  end
end
