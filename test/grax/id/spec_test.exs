defmodule Grax.Id.SpecTest do
  use Grax.TestCase

  alias Grax.Id
  alias RDF.PrefixMap
  alias Example.{IdSpecs, User, Post, Comment}

  describe "namespaces/0" do
    test "returns all namespaces" do
      namespace = %Id.Namespace{
        segment: "http://example.com/",
        prefix: :ex,
        base: false
      }

      assert IdSpecs.FlatNs.namespaces() == [namespace]
      assert IdSpecs.FlatNsWithVocabTerms.namespaces() == [namespace]
    end

    test "includes base namespaces" do
      assert IdSpecs.FlatBase.namespaces() == [
               %Id.Namespace{
                 segment: "http://example.com/",
                 base: true
               }
             ]
    end

    test "includes nested namespaces" do
      root_namespace = %Id.Namespace{
        segment: "http://example.com/",
        prefix: :ex,
        base: false
      }

      foo_namespace = %Id.Namespace{
        parent: root_namespace,
        segment: "foo/",
        prefix: :foo,
        base: false
      }

      assert IdSpecs.NestedNs.namespaces() == [
               %Id.Namespace{
                 parent: root_namespace,
                 segment: "qux/",
                 prefix: :qux,
                 base: false
               },
               %Id.Namespace{
                 parent: foo_namespace,
                 segment: "baz/",
                 prefix: :baz,
                 base: false
               },
               %Id.Namespace{
                 parent: foo_namespace,
                 segment: "bar/",
                 prefix: :bar,
                 base: false
               },
               foo_namespace,
               root_namespace
             ]
    end
  end

  describe "id_schemas/0" do
    test "returns all namespaces" do
      assert IdSpecs.GenericIds.id_schemas() ==
               [
                 IdSpecs.GenericIds.expected_id_schema(Post),
                 IdSpecs.GenericIds.expected_id_schema(User)
               ]

      assert IdSpecs.GenericUuids.id_schemas() ==
               [
                 IdSpecs.GenericUuids.expected_id_schema(Comment),
                 IdSpecs.GenericUuids.expected_id_schema(Post),
                 IdSpecs.GenericUuids.expected_id_schema(User)
               ]

      assert IdSpecs.HashUuids.id_schemas() ==
               [
                 IdSpecs.HashUuids.expected_id_schema(Post),
                 IdSpecs.HashUuids.expected_id_schema(User)
               ]
    end
  end

  describe "determine_id_schema/2" do
    test "when an Id.Schema can be found for a given Grax schema module" do
      assert Id.Spec.determine_id_schema(IdSpecs.GenericIds, User) ==
               IdSpecs.GenericIds.expected_id_schema(User)

      assert Id.Spec.determine_id_schema(IdSpecs.GenericIds, Post) ==
               IdSpecs.GenericIds.expected_id_schema(Post)
    end
  end

  describe "prefix_map/0" do
    test "returns a RDF.PrefixMap of all namespaces with prefixes defined" do
      assert IdSpecs.FlatNs.prefix_map() == PrefixMap.new(ex: EX)
      assert IdSpecs.FlatNsWithVocabTerms.prefix_map() == PrefixMap.new(ex: EX)
      assert IdSpecs.FlatBase.prefix_map() == PrefixMap.new()

      assert IdSpecs.NestedNs.prefix_map() ==
               PrefixMap.new(
                 ex: EX,
                 foo: "#{EX.foo()}/",
                 bar: "#{EX.foo()}/bar/",
                 baz: "#{EX.foo()}/baz/",
                 qux: EX.__base_iri__() <> "qux/"
               )
    end
  end
end
