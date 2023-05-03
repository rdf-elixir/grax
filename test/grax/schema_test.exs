defmodule Grax.SchemaTest do
  use Grax.TestCase

  alias Example.{IdSpecs, User, Post, Comment}

  describe "default values" do
    test "on properties and links" do
      assert %Example.DefaultValues{} ==
               %Example.DefaultValues{
                 foo: "foo",
                 bar: "bar",
                 baz: 42,
                 user: nil,
                 posts: []
               }
    end

    test "links don't support custom defaults" do
      assert_raise ArgumentError, "the :default option is not supported on links", fn ->
        defmodule LinkWithDefault do
          use Grax.Schema

          schema do
            link a: EX.a(), type: A, default: :foo
          end
        end
      end
    end

    test "property sets don't support custom defaults" do
      assert_raise ArgumentError, "the :default option is not supported on sets", fn ->
        defmodule LinkWithDefault do
          use Grax.Schema

          schema do
            property a: EX.a(), type: list(), default: :foo
          end
        end
      end
    end
  end

  test "type of default values must match the type" do
    assert_raise ArgumentError,
                 ~S(default value "foo" doesn't match type RDF.XSD.Integer),
                 fn ->
                   defmodule DefaultValueTypeMismatch do
                     use Grax.Schema

                     schema do
                       property a: EX.a(), type: :integer, default: "foo"
                     end
                   end
                 end
  end

  test "links without a type raise a proper error" do
    assert_raise ArgumentError, "invalid type definition for property a: type missing", fn ->
      defmodule NilLink do
        use Grax.Schema

        schema do
          link a: EX.a(), type: nil
        end
      end
    end
  end

  describe "cardinality" do
    test "property schema" do
      assert Example.Cardinalities.__property__(:p1).cardinality == 2
      assert Example.Cardinalities.__property__(:p2).cardinality == 2..4
      assert Example.Cardinalities.__property__(:p3).cardinality == {:min, 3}
      assert Example.Cardinalities.__property__(:l1).cardinality == 2..3
      assert Example.Cardinalities.__property__(:l2).cardinality == {:min, 2}
    end

    test "normalization of equivalent cardinalities" do
      defmodule EquivalentCardinalities do
        use Grax.Schema

        schema do
          property p1: EX.p1(), type: list(card: 1..1)
          property p2: EX.p2(), type: list(card: 3..2)
          property p3: EX.p3(), type: list(min: 0)
        end
      end

      assert EquivalentCardinalities.__property__(:p1).cardinality == 1
      assert EquivalentCardinalities.__property__(:p2).cardinality == 2..3
      assert EquivalentCardinalities.__property__(:p3).cardinality == nil
    end

    test "mapping of required flag to cardinalities" do
      defmodule RequiredAsCardinalities do
        use Grax.Schema

        schema do
          property p1: EX.p1(), type: :string, required: true
          property p2: EX.p1(), type: :string, required: false
          property p3: EX.p3(), type: list(), required: true
          property p4: EX.p4(), type: list(), required: false
          link l1: EX.l1(), type: User, required: true
          link l2: EX.l2(), type: list_of(User), required: true
        end
      end

      assert RequiredAsCardinalities.__property__(:p1).cardinality == 1
      assert RequiredAsCardinalities.__property__(:p2).cardinality == nil
      assert RequiredAsCardinalities.__property__(:p3).cardinality == {:min, 1}
      assert RequiredAsCardinalities.__property__(:p4).cardinality == nil
      assert RequiredAsCardinalities.__property__(:l1).cardinality == 1
      assert RequiredAsCardinalities.__property__(:l2).cardinality == {:min, 1}
    end

    test "required flag with cardinalities causes an error" do
      error_message =
        "property foo: required option is not allowed when cardinality constraints are given"

      assert_raise ArgumentError, error_message, fn ->
        defmodule RequiredWithCardinalities1 do
          use Grax.Schema

          schema do
            property foo: EX.foo(), type: list(card: 2), required: true
          end
        end
      end

      assert_raise ArgumentError, error_message, fn ->
        defmodule RequiredWithCardinalities2 do
          use Grax.Schema

          schema do
            link foo: EX.foo(), type: list_of(User, card: 2..3), required: true
          end
        end
      end
    end
  end

  test "__class__/0" do
    assert Example.ClassDeclaration.__class__() == IRI.to_string(EX.Class)
    assert Example.Datatypes.__class__() == nil
  end

  test "__load_additional_statements__?/0" do
    assert Example.User.__load_additional_statements__?() == true
    assert Example.IgnoreAdditionalStatements.__load_additional_statements__?() == false
  end

  describe "__id_spec__/0" do
    test "when no id spec set or application configured" do
      assert User.__id_spec__() == nil
    end

    test "when an id spec is set explicitly" do
      assert Example.WithIdSchema.__id_spec__() == IdSpecs.Foo
    end

    # tests for the application configured Id.Spec are in Grax.ConfigTest
  end

  describe "__id_schema__/0" do
    test "when no id spec set or application configured" do
      assert User.__id_schema__() == nil
    end

    test "when an id spec is set explicitly" do
      assert Example.WithIdSchema.__id_schema__() ==
               IdSpecs.Foo.expected_id_schema(Example.WithIdSchema)
    end

    # tests for the application configured Id.Spec are in Grax.ConfigTest
  end

  describe "__id_schema__/1" do
    test "when an Id.Schema can be found for a given Grax schema module" do
      assert User.__id_schema__(IdSpecs.GenericIds) ==
               IdSpecs.GenericIds.expected_id_schema(User)

      assert Post.__id_schema__(IdSpecs.GenericIds) ==
               IdSpecs.GenericIds.expected_id_schema(Post)
    end

    test "BlankNode" do
      assert User.__id_schema__(IdSpecs.BlankNodes) ==
               IdSpecs.BlankNodes.expected_id_schema(User)

      assert Post.__id_schema__(IdSpecs.BlankNodes) ==
               IdSpecs.BlankNodes.expected_id_schema(Example.WithBlankNodeIdSchema)
               |> Map.put(:schema, Post)

      assert Comment.__id_schema__(IdSpecs.BlankNodes) ==
               IdSpecs.BlankNodes.expected_id_schema(Example.WithBlankNodeIdSchema)
               |> Map.put(:schema, Comment)

      assert Example.WithBlankNodeIdSchema.__id_schema__(IdSpecs.BlankNodes) ==
               IdSpecs.BlankNodes.expected_id_schema(Example.WithBlankNodeIdSchema)
               |> Map.put(:schema, Example.WithBlankNodeIdSchema)
    end

    test "with an Id.Schema for multiple Grax schema modules" do
      assert Example.MultipleSchemasA.__id_schema__(IdSpecs.MultipleSchemas) ==
               IdSpecs.MultipleSchemas.expected_id_schema(:foo)
               |> Map.put(:schema, Example.MultipleSchemasA)

      assert Example.MultipleSchemasB.__id_schema__(IdSpecs.MultipleSchemas) ==
               IdSpecs.MultipleSchemas.expected_id_schema(:foo)
               |> Map.put(:schema, Example.MultipleSchemasB)

      assert Post.__id_schema__(IdSpecs.MultipleSchemas) ==
               IdSpecs.MultipleSchemas.expected_id_schema(:content)
               |> Map.put(:schema, Post)

      assert Comment.__id_schema__(IdSpecs.MultipleSchemas) ==
               IdSpecs.MultipleSchemas.expected_id_schema(:content)
               |> Map.put(:schema, Comment)
    end

    test "when no Id.Schema can be found" do
      assert Comment.__id_schema__(IdSpecs.GenericIds) == nil
    end
  end
end
