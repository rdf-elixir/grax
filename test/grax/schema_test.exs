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

  describe "inheritance" do
    test "struct fields are inherited" do
      assert Example.ChildSchema.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               MapSet.new(~w[__id__ __additional_statements__ dp1 dp2 dp3 lp1 lp2 lp3 f1 f2 f3]a)

      assert Example.ChildSchemaWithClass.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               Example.ParentSchema.build!(EX.S)
               |> Map.from_struct()
               |> Map.keys()
               |> MapSet.new()
    end

    test "properties are inherited" do
      assert Example.ChildSchema.__properties__() == %{
               dp1: %Grax.Schema.DataProperty{
                 name: :dp1,
                 iri: ~I<http://example.com/dp1>,
                 schema: Example.ChildSchema,
                 from_rdf: {Example.ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp22>,
                 schema: Example.ChildSchema
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: Example.ChildSchema
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: Example.ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp22>,
                 schema: Example.ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: Example.ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               }
             }
    end

    test "custom fields are inherited" do
      assert Example.ChildSchema.__custom_fields__() == %{
               f1: %Grax.Schema.CustomField{name: :f1, default: :foo},
               f2: %Grax.Schema.CustomField{name: :f2, from_rdf: {Example.ChildSchema, :foo}},
               f3: %Grax.Schema.CustomField{name: :f3}
             }
    end

    test "multiple inheritance" do
      assert Example.ChildOfMany.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               MapSet.new(
                 ~w[__id__ __additional_statements__ dp1 dp2 dp3 dp4 lp1 lp2 lp3 lp4 f1 f2 f3 f4]a
               )

      assert Example.ChildOfMany.__properties__() == %{
               dp1: %Grax.Schema.DataProperty{
                 name: :dp1,
                 iri: ~I<http://example.com/dp1>,
                 schema: Example.ChildOfMany,
                 from_rdf: {Example.ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp23>,
                 schema: Example.ChildOfMany
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: Example.ChildOfMany
               },
               dp4: %Grax.Schema.DataProperty{
                 name: :dp4,
                 iri: ~I<http://example.com/dp4>,
                 schema: Example.ChildOfMany
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp2>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp4: %Grax.Schema.LinkProperty{
                 name: :lp4,
                 iri: ~I<http://example.com/lp4>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               }
             }

      assert Example.ChildOfMany.__custom_fields__() == %{
               f1: %Grax.Schema.CustomField{name: :f1},
               f2: %Grax.Schema.CustomField{name: :f2},
               f3: %Grax.Schema.CustomField{name: :f3},
               f4: %Grax.Schema.CustomField{name: :f4}
             }
    end

    test "inherit from nil" do
      defmodule InheritingFromNil do
        use Grax.Schema

        schema EX.Foo < nil do
          property foo: EX.foo()
        end
      end

      assert InheritingFromNil.__super__() == nil
    end

    test "multiple inheritance with conflicting property definitions" do
      assert_raise RuntimeError, fn ->
        defmodule ChildOfConflictingSchemas do
          use Grax.Schema

          schema inherit: [Example.ParentSchema, Example.AnotherParentSchema] do
          end
        end
      end

      assert_raise RuntimeError, fn ->
        defmodule ChildOfConflictingSchemas2 do
          use Grax.Schema

          schema inherit: [Example.ParentSchema, Example.AnotherParentSchema] do
            property dp2: EX.dp23()
          end
        end
      end
    end
  end

  test "__super__/0" do
    assert Example.ChildSchema.__super__() == [Example.ParentSchema]
    assert Example.ChildSchemaWithClass.__super__() == [Example.ParentSchema]

    assert Example.ChildOfMany.__super__() == [
             Example.ParentSchema,
             Example.AnotherParentSchema,
             Example.ChildSchemaWithClass
           ]

    assert Example.ParentSchema.__super__() == nil
  end

  test "__class__/0" do
    assert Example.ClassDeclaration.__class__() == IRI.to_string(EX.Class)
    assert Example.ChildSchemaWithClass.__class__() == IRI.to_string(EX.Class)
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
