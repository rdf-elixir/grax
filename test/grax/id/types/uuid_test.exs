defmodule Grax.Id.Types.UuidTest do
  use Grax.TestCase

  alias Grax.Id
  alias Example.{IdSpecs, User, Post, Comment}

  describe "generic uuid macro" do
    test "random UUIDs" do
      assert {:ok, %RDF.IRI{value: "http://example.com/" <> uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.GenericUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      assert_valid_uuid(uuid, version: 4, type: :hex)

      assert {:ok, %RDF.IRI{value: "http://example.com/" <> id_segment}} =
               Id.Schema.generate_id(
                 IdSpecs.GenericUuids.expected_id_schema(Post),
                 Example.post()
               )

      assert "posts/" <> uuid = id_segment
      assert_valid_uuid(uuid, version: 4, type: :default)

      assert {:ok, %RDF.IRI{value: "http://example.com/" <> uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(Post),
                 Example.post()
               )

      assert_valid_uuid(uuid, version: 4, type: :default)

      assert {:ok, %RDF.IRI{value: "http://example.com/" <> id_segment}} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(Comment),
                 Example.comment(EX.Comment1, depth: 0)
               )

      assert "comments/" <> uuid = id_segment
      assert_valid_uuid(uuid, version: 1, type: :hex)
    end

    test "hash-based UUIDs" do
      assert {:ok, %RDF.IRI{value: "http://example.com/" <> uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      # test that the generated UUIDs are reproducible
      assert {:ok, %RDF.IRI{value: "http://example.com/" <> ^uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      assert_valid_uuid(uuid, version: 5, type: :default)

      assert {:ok, %RDF.IRI{value: "http://example.com/" <> uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(Post),
                 Example.post()
               )

      # test that the generated UUIDs are reproducible
      assert {:ok, %RDF.IRI{value: "http://example.com/" <> ^uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.HashUuids.expected_id_schema(Post),
                 Example.post()
               )

      assert_valid_uuid(uuid, version: 3, type: :default)

      assert {:ok, %RDF.IRI{value: "http://example.com/" <> uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      # test that the generated UUIDs are reproducible
      assert {:ok, %RDF.IRI{value: "http://example.com/" <> ^uuid}} =
               Id.Schema.generate_id(
                 IdSpecs.ShortUuids.expected_id_schema(User),
                 Example.user(EX.User0)
               )

      assert_valid_uuid(uuid, version: 5, type: :hex)
    end
  end

  def assert_valid_uuid(uuid, opts) do
    assert {:ok, info} = UUID.info(uuid)

    if expected_version = Keyword.get(opts, :version) do
      version = Keyword.get(info, :version)

      assert version == expected_version,
             "UUID version mismatch; expected #{expected_version}, but got #{version}"
    end

    if expected_type = Keyword.get(opts, :type) do
      type = Keyword.get(info, :type)

      assert type == expected_type,
             "UUID type mismatch; expected #{expected_type}, but got #{type}"
    end

    if expected_variant = Keyword.get(opts, :variant) do
      variant = Keyword.get(info, :variant)

      assert variant == expected_variant,
             "UUID type mismatch; expected #{expected_variant}, but got #{variant}"
    end
  end
end
