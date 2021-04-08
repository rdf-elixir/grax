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

  test "vocab terms are only allowed on the top-level namespace" do
    assert_raise ArgumentError, "absolute URIs are only allowed on the top-level namespace", fn ->
      defmodule VocabTermsOnNestedNamespace do
        use Grax.Id.Spec

        namespace "http://example.com/" do
          namespace EX do
          end
        end
      end
    end
  end

  describe "id_schemas/0" do
    test "returns all id schemas" do
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

      assert IdSpecs.ShortUuids.id_schemas() ==
               [
                 IdSpecs.ShortUuids.expected_id_schema(Comment),
                 IdSpecs.ShortUuids.expected_id_schema(Post),
                 IdSpecs.ShortUuids.expected_id_schema(User)
               ]
    end

    test "id schemas with var_proc" do
      assert IdSpecs.VarProc.id_schemas() ==
               [
                 IdSpecs.VarProc.expected_id_schema(Example.VarProcB),
                 IdSpecs.VarProc.expected_id_schema(Example.VarProcA)
               ]
    end

    test "id schemas with custom selectors" do
      assert IdSpecs.CustomSelector.id_schemas() ==
               [
                 IdSpecs.CustomSelector.expected_id_schema(:uuid4),
                 IdSpecs.CustomSelector.expected_id_schema(:uuid5),
                 IdSpecs.CustomSelector.expected_id_schema(:foo)
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

    test "when no Id.Schema can be found" do
      assert Id.Spec.determine_id_schema(IdSpecs.GenericIds, Comment) == nil
    end
  end

  describe "custom_select_id_schema/2" do
    test "when Id.Schema can be found" do
      assert Id.Spec.custom_select_id_schema(
               IdSpecs.CustomSelector,
               Example.WithCustomSelectedIdSchemaA,
               %{}
             ) ==
               %{
                 IdSpecs.CustomSelector.expected_id_schema(:foo)
                 | schema: Example.WithCustomSelectedIdSchemaA
               }

      assert Id.Spec.custom_select_id_schema(
               IdSpecs.CustomSelector,
               Example.WithCustomSelectedIdSchemaB,
               %{bar: "bar"}
             ) ==
               %{
                 IdSpecs.CustomSelector.expected_id_schema(:uuid4)
                 | schema: Example.WithCustomSelectedIdSchemaB
               }

      assert Id.Spec.custom_select_id_schema(
               IdSpecs.CustomSelector,
               Example.WithCustomSelectedIdSchemaB,
               %{bar: "test"}
             ) ==
               %{
                 IdSpecs.CustomSelector.expected_id_schema(:uuid5)
                 | schema: Example.WithCustomSelectedIdSchemaB
               }
    end

    test "when no Id.Schema can be found" do
      assert Id.Spec.custom_select_id_schema(
               IdSpecs.CustomSelector,
               Example.WithCustomSelectedIdSchemaB,
               %{bar: ""}
             ) ==
               nil
    end
  end

  test "multiple usages of the same custom selector raises an error" do
    assert_raise ArgumentError,
                 "custom selector {Grax.Id.SpecTest.MultipleCustomSelectorUsage, :test_selector} is already used for another id schema",
                 fn ->
                   defmodule MultipleCustomSelectorUsage do
                     use Grax.Id.Spec

                     namespace "http://example.com/" do
                       id_schema "foo/{foo}", selector: :test_selector
                       id_schema "bar/{bar}", selector: :test_selector
                     end

                     def test_selector(_, _), do: true
                   end
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
