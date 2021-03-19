defmodule Grax.Id.SpecTest do
  use Grax.TestCase

  alias Grax.Id.Namespace
  alias RDF.PrefixMap
  alias Example.IdSpec

  describe "namespaces/1" do
    test "returns all namespaces" do
      namespace = %Namespace{
        segment: "http://example.com/",
        prefix: :ex,
        base: false
      }

      assert IdSpec.FlatNs.namespaces() == [namespace]
      assert IdSpec.FlatNsWithVocabTerms.namespaces() == [namespace]
    end

    test "includes base namespaces" do
      assert IdSpec.FlatBase.namespaces() == [
               %Namespace{
                 segment: "http://example.com/",
                 base: true
               }
             ]
    end

    test "includes nested namespaces" do
      root_namespace = %Namespace{
        segment: "http://example.com/",
        prefix: :ex,
        base: false
      }

      foo_namespace = %Namespace{
        parent: root_namespace,
        segment: "foo/",
        prefix: :foo,
        base: false
      }

      assert IdSpec.NestedNs.namespaces() == [
               %Namespace{
                 parent: root_namespace,
                 segment: "qux/",
                 prefix: :qux,
                 base: false
               },
               %Namespace{
                 parent: foo_namespace,
                 segment: "baz/",
                 prefix: :baz,
                 base: false
               },
               %Namespace{
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

  describe "prefix_map/1" do
    test "returns a RDF.PrefixMap of all namespaces with prefixes defined" do
      assert IdSpec.FlatNs.prefix_map() == PrefixMap.new(ex: EX)
      assert IdSpec.FlatNsWithVocabTerms.prefix_map() == PrefixMap.new(ex: EX)
      assert IdSpec.FlatBase.prefix_map() == PrefixMap.new()

      assert IdSpec.NestedNs.prefix_map() ==
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
