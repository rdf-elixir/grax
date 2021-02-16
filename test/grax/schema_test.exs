defmodule Grax.SchemaTest do
  use Grax.TestCase

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
            property a: EX.a(), type: [], default: :foo
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
    assert_raise ArgumentError, "type missing for property a", fn ->
      defmodule NilLink do
        use Grax.Schema

        schema do
          link a: EX.a(), type: nil
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
               MapSet.new(~w[__id__ dp1 dp2 dp3 lp1 lp2 lp3 f1 f2 f3]a)

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
                 required: false,
                 from_rdf: {Example.ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp22>,
                 schema: Example.ChildSchema,
                 required: false
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: Example.ChildSchema,
                 required: false
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: Example.ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, Example.User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp22>,
                 schema: Example.ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, Example.User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: Example.ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, Example.User}
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
               MapSet.new(~w[__id__ dp1 dp2 dp3 dp4 lp1 lp2 lp3 lp4 f1 f2 f3 f4]a)

      assert Example.ChildOfMany.__properties__() == %{
               dp1: %Grax.Schema.DataProperty{
                 name: :dp1,
                 iri: ~I<http://example.com/dp1>,
                 schema: Example.ChildOfMany,
                 required: false,
                 from_rdf: {Example.ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp23>,
                 schema: Example.ChildOfMany,
                 required: false
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: Example.ChildOfMany,
                 required: false
               },
               dp4: %Grax.Schema.DataProperty{
                 name: :dp4,
                 iri: ~I<http://example.com/dp4>,
                 schema: Example.ChildOfMany,
                 required: false
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, Example.User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp2>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, Example.User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, Example.User}
               },
               lp4: %Grax.Schema.LinkProperty{
                 name: :lp4,
                 iri: ~I<http://example.com/lp4>,
                 schema: Example.ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, Example.User}
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
    assert Example.ChildOfMany.__super__() == [Example.ParentSchema, Example.AnotherParentSchema]
    assert Example.ParentSchema.__super__() == nil
  end

  test "__class__/0" do
    assert Example.ClassDeclaration.__class__() == IRI.to_string(EX.Class)
    assert Example.ChildSchemaWithClass.__class__() == IRI.to_string(EX.Class)
    assert Example.Datatypes.__class__() == nil
  end
end
