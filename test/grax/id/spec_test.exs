defmodule Grax.Id.SpecTest do
  use Grax.TestCase

  alias Grax.Id
  alias RDF.PrefixMap
  alias Example.{IdSpecs, User, Post, Comment}

  describe "namespaces/0" do
    test "returns all namespaces" do
      namespace = %Id.Namespace{uri: "http://example.com/", prefix: :ex}

      assert IdSpecs.FlatNs.namespaces() == [namespace]
      assert IdSpecs.FlatNsWithVocabTerms.namespaces() == [namespace]
    end

    test "includes base namespaces" do
      assert IdSpecs.FlatBase.namespaces() == [
               %Id.Namespace{uri: "http://example.com/"}
             ]
    end

    test "includes URN namespaces" do
      assert IdSpecs.UrnNs.namespaces() == [
               %Id.UrnNamespace{nid: :uuid, string: "urn:uuid:"},
               %Id.UrnNamespace{nid: :isbn, string: "urn:isbn:"}
             ]
    end

    test "includes nested namespaces" do
      root_namespace = %Id.Namespace{uri: "http://example.com/", prefix: :ex}

      foo_namespace = %Id.Namespace{
        parent: root_namespace,
        uri: "http://example.com/foo/",
        prefix: :foo
      }

      assert IdSpecs.NestedNs.namespaces() == [
               %Id.Namespace{
                 parent: root_namespace,
                 uri: "http://example.com/qux/",
                 prefix: :qux
               },
               %Id.Namespace{
                 parent: foo_namespace,
                 uri: "http://example.com/foo/baz/",
                 prefix: :baz
               },
               %Id.Namespace{
                 parent: foo_namespace,
                 uri: "http://example.com/foo/bar/",
                 prefix: :bar
               },
               foo_namespace,
               root_namespace
             ]
    end

    test "expressions in namespaces" do
      root_namespace = %Id.Namespace{uri: "http://example.com/"}

      assert IdSpecs.NsWithExpressions.namespaces() == [
               %Id.Namespace{parent: root_namespace, uri: "http://example.com/sub/"},
               root_namespace
             ]

      assert IdSpecs.NsWithExpressions2.namespaces() == [
               %Id.Namespace{root_namespace | prefix: :ex}
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

  test "urn namespaces are only allowed on the top-level" do
    assert_raise RuntimeError, "urn namespaces can only be defined on the top-level", fn ->
      defmodule VocabTermsOnNestedNamespace do
        use Grax.Id.Spec

        namespace "http://example.com/" do
          urn :uuid do
          end
        end
      end
    end
  end

  test "only one base namespace allowed" do
    assert_raise RuntimeError, "already a base namespace defined: http://example.com/foo/", fn ->
      defmodule VocabTermsOnNestedNamespace do
        use Grax.Id.Spec

        namespace "http://example.com/" do
          base "foo/" do
          end

          base "bar/" do
          end
        end
      end
    end
  end

  describe "base_namespace/0" do
    test "when base namespace defined" do
      assert IdSpecs.FlatBase.base_namespace() ==
               %Id.Namespace{uri: "http://example.com/"}

      assert IdSpecs.NestedBase.base_namespace() ==
               %Id.Namespace{
                 parent: %Id.Namespace{uri: "http://example.com/"},
                 uri: "http://example.com/foo/"
               }
    end

    test "when no base namespace defined" do
      refute IdSpecs.FlatNs.base_namespace()
      refute IdSpecs.FlatNsWithVocabTerms.base_namespace()
      refute IdSpecs.NestedNs.base_namespace()
    end
  end

  describe "base_iri/0" do
    test "when base namespace defined" do
      assert IdSpecs.FlatBase.base_iri() == ~I<http://example.com/>
      assert IdSpecs.NestedBase.base_iri() == ~I<http://example.com/foo/>
    end

    test "when no base namespace defined" do
      refute IdSpecs.FlatNs.base_iri()
      refute IdSpecs.FlatNsWithVocabTerms.base_iri()
      refute IdSpecs.NestedNs.base_iri()
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

  describe "id_schemas/0" do
    test "returns all id schemas" do
      assert IdSpecs.GenericIds.id_schemas() ==
               [
                 IdSpecs.GenericIds.expected_id_schema(Post),
                 IdSpecs.GenericIds.expected_id_schema(User)
               ]

      assert IdSpecs.GenericShortIds.id_schemas() ==
               [
                 IdSpecs.GenericShortIds.expected_id_schema(Post),
                 IdSpecs.GenericShortIds.expected_id_schema(User)
               ]

      assert IdSpecs.UrnIds.id_schemas() ==
               [
                 IdSpecs.UrnIds.expected_id_schema(:integer),
                 IdSpecs.UrnIds.expected_id_schema(Post),
                 IdSpecs.UrnIds.expected_id_schema(User)
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
                 IdSpecs.ShortUuids.expected_id_schema(Example.SelfLinked),
                 IdSpecs.ShortUuids.expected_id_schema(Comment),
                 IdSpecs.ShortUuids.expected_id_schema(Post),
                 IdSpecs.ShortUuids.expected_id_schema(User)
               ]

      assert IdSpecs.Hashing.id_schemas() ==
               [
                 IdSpecs.Hashing.expected_id_schema(Comment),
                 IdSpecs.Hashing.expected_id_schema(Post),
                 IdSpecs.Hashing.expected_id_schema(User)
               ]

      assert IdSpecs.HashUrns.id_schemas() ==
               [
                 IdSpecs.HashUrns.expected_id_schema(Comment),
                 IdSpecs.HashUrns.expected_id_schema(Post)
               ]

      assert IdSpecs.UuidUrns.id_schemas() ==
               [
                 IdSpecs.UuidUrns.expected_id_schema(Post),
                 IdSpecs.UuidUrns.expected_id_schema(User)
               ]

      assert IdSpecs.BlankNodes.id_schemas() ==
               [
                 IdSpecs.BlankNodes.expected_id_schema(Example.Datatypes),
                 IdSpecs.BlankNodes.expected_id_schema(Example.WithBlankNodeIdSchema),
                 IdSpecs.BlankNodes.expected_id_schema(Example.SelfLinked),
                 IdSpecs.BlankNodes.expected_id_schema(User)
               ]

      assert IdSpecs.WithCounter.id_schemas() ==
               [
                 IdSpecs.WithCounter.expected_id_schema(Comment),
                 IdSpecs.WithCounter.expected_id_schema(Post),
                 IdSpecs.WithCounter.expected_id_schema(User)
               ]

      assert IdSpecs.OptionInheritance.id_schemas() ==
               [
                 IdSpecs.OptionInheritance.expected_id_schema(Example.Datatypes),
                 IdSpecs.OptionInheritance.expected_id_schema(Example.SelfLinked),
                 IdSpecs.OptionInheritance.expected_id_schema(Comment),
                 IdSpecs.OptionInheritance.expected_id_schema(Post),
                 IdSpecs.OptionInheritance.expected_id_schema(User)
               ]
    end

    test "id schemas for multiple schemas" do
      assert IdSpecs.MultipleSchemas.id_schemas() ==
               [
                 IdSpecs.MultipleSchemas.expected_id_schema(:content),
                 IdSpecs.MultipleSchemas.expected_id_schema(:foo)
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

    test "id schemas with var_mapping" do
      assert IdSpecs.VarMapping.id_schemas() ==
               [
                 IdSpecs.VarMapping.expected_id_schema(Example.VarMappingC),
                 IdSpecs.VarMapping.expected_id_schema(Example.VarMappingB),
                 IdSpecs.VarMapping.expected_id_schema(Example.VarMappingA)
               ]
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
end
