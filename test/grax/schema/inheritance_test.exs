defmodule Grax.Schema.InheritanceTest do
  use Grax.TestCase

  alias Grax.Schema.Inheritance
  alias Grax.InvalidResourceTypeError

  alias Example.User

  defmodule ParentSchema do
    use Grax.Schema

    schema do
      property dp1: EX.dp1(), from_rdf: :upcase
      property dp2: EX.dp2()

      field :f1, default: :foo
      field :f2

      link lp1: EX.lp1(), type: User
      link lp2: EX.lp2(), type: User
    end

    def upcase([foo], _, _), do: {:ok, foo |> to_string |> String.upcase()}
  end

  defmodule ChildSchema do
    use Grax.Schema

    schema inherit: ParentSchema do
      property dp2: EX.dp22()
      property dp3: EX.dp3()

      field :f2, from_rdf: :foo
      field :f3

      link lp2: EX.lp22(), type: User
      link lp3: EX.lp3(), type: User
    end

    def foo(_, _), do: {:ok, :foo}
  end

  defmodule ChildSchemaWithClass do
    use Grax.Schema

    schema EX.Class < ParentSchema do
    end
  end

  defmodule AnotherParentSchema do
    use Grax.Schema

    schema do
      property dp1: EX.dp1(), from_rdf: {ParentSchema, :upcase}
      property dp2: EX.dp22()
      property dp3: EX.dp3()

      field :f1
      field :f2
      field :f3

      link lp1: EX.lp1(), type: User
      link lp3: EX.lp3(), type: User
    end
  end

  defmodule ChildOfMany do
    use Grax.Schema

    schema EX.SubClass < [ParentSchema, AnotherParentSchema, ChildSchemaWithClass] do
      property dp2: EX.dp23()
      property dp4: EX.dp4()

      field :f1
      field :f4

      link lp4: EX.lp4(), type: User
    end

    def foo(_, _), do: {:ok, :foo}
  end

  defmodule PolymorphicLinkWithInheritance do
    use Grax.Schema

    schema do
      property name: EX.name()

      link linked: EX.linked(),
           type: %{
             EX.ParentSchema => ParentSchema,
             EX.ChildSchema => ChildSchema,
             EX.ChildSchemaWithClass => ChildSchemaWithClass,
             EX.ChildOfMany => ChildOfMany
           },
           on_type_mismatch: :error
    end
  end

  test "__super__/0" do
    assert ChildSchema.__super__() == [ParentSchema]
    assert ChildSchemaWithClass.__super__() == [ParentSchema]

    assert ChildOfMany.__super__() == [
             ParentSchema,
             AnotherParentSchema,
             ChildSchemaWithClass
           ]

    assert ParentSchema.__super__() == nil
  end

  test "__class__/0" do
    assert ChildSchemaWithClass.__class__() == IRI.to_string(EX.Class)
  end

  describe "field inheritance" do
    test "struct fields are inherited" do
      assert ChildSchema.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               MapSet.new(~w[__id__ __additional_statements__ dp1 dp2 dp3 lp1 lp2 lp3 f1 f2 f3]a)

      assert ChildSchemaWithClass.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               ParentSchema.build!(EX.S)
               |> Map.from_struct()
               |> Map.keys()
               |> MapSet.new()
    end

    test "properties are inherited" do
      assert ChildSchema.__properties__() == %{
               dp1: %Grax.Schema.DataProperty{
                 name: :dp1,
                 iri: ~I<http://example.com/dp1>,
                 schema: ChildSchema,
                 from_rdf: {ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp22>,
                 schema: ChildSchema
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: ChildSchema
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp22>,
                 schema: ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: ChildSchema,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               }
             }
    end

    test "custom fields are inherited" do
      assert ChildSchema.__custom_fields__() == %{
               f1: %Grax.Schema.CustomField{name: :f1, default: :foo},
               f2: %Grax.Schema.CustomField{name: :f2, from_rdf: {ChildSchema, :foo}},
               f3: %Grax.Schema.CustomField{name: :f3}
             }
    end

    test "multiple inheritance" do
      assert ChildOfMany.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               MapSet.new(
                 ~w[__id__ __additional_statements__ dp1 dp2 dp3 dp4 lp1 lp2 lp3 lp4 f1 f2 f3 f4]a
               )

      assert ChildOfMany.__properties__() == %{
               dp1: %Grax.Schema.DataProperty{
                 name: :dp1,
                 iri: ~I<http://example.com/dp1>,
                 schema: ChildOfMany,
                 from_rdf: {ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp23>,
                 schema: ChildOfMany
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: ChildOfMany
               },
               dp4: %Grax.Schema.DataProperty{
                 name: :dp4,
                 iri: ~I<http://example.com/dp4>,
                 schema: ChildOfMany
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp2>,
                 schema: ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               },
               lp4: %Grax.Schema.LinkProperty{
                 name: :lp4,
                 iri: ~I<http://example.com/lp4>,
                 schema: ChildOfMany,
                 on_type_mismatch: :ignore,
                 type: {:resource, User}
               }
             }

      assert ChildOfMany.__custom_fields__() == %{
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

          schema inherit: [ParentSchema, AnotherParentSchema] do
          end
        end
      end

      assert_raise RuntimeError, fn ->
        defmodule ChildOfConflictingSchemas2 do
          use Grax.Schema

          schema inherit: [ParentSchema, AnotherParentSchema] do
            property dp2: EX.dp23()
          end
        end
      end
    end
  end

  describe "preloading" do
    test "when multiple classes are matching which are related via inheritance" do
      assert RDF.graph([
               EX.A |> EX.linked(EX.B),
               EX.B |> RDF.type([EX.ParentSchema, EX.ChildSchema])
             ])
             |> PolymorphicLinkWithInheritance.load(EX.A) ==
               PolymorphicLinkWithInheritance.build(EX.A,
                 linked:
                   ChildSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.ParentSchema, EX.ChildSchema]},
                     f2: :foo
                   )
               )

      assert RDF.graph([
               EX.A |> EX.linked(EX.B),
               EX.B
               |> RDF.type([
                 EX.ParentSchema,
                 EX.ChildSchemaWithClass,
                 EX.ChildOfMany
               ])
             ])
             |> PolymorphicLinkWithInheritance.load(EX.A) ==
               PolymorphicLinkWithInheritance.build(EX.A,
                 linked:
                   ChildOfMany.build!(EX.B,
                     __additional_statements__: %{
                       RDF.type() => [
                         EX.SubClass,
                         EX.ParentSchema,
                         EX.ChildSchemaWithClass,
                         EX.ChildOfMany
                       ]
                     }
                   )
               )

      assert RDF.graph([
               EX.A |> EX.linked(EX.B),
               EX.B
               |> RDF.type([
                 EX.ParentSchema,
                 EX.ChildSchema,
                 EX.ChildSchemaWithClass,
                 EX.ChildOfMany
               ])
             ])
             |> PolymorphicLinkWithInheritance.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [ChildSchema, ChildOfMany]
                )}
    end
  end

  test "paths/1" do
    assert Inheritance.paths(User) == []
    assert Inheritance.paths(ParentSchema) == []
    assert Inheritance.paths(ChildSchema) == [[ParentSchema]]
    assert Inheritance.paths(ChildSchemaWithClass) == [[ParentSchema]]

    assert Inheritance.paths(ChildOfMany) == [
             [ParentSchema],
             [AnotherParentSchema],
             [ChildSchemaWithClass, ParentSchema]
           ]
  end
end
