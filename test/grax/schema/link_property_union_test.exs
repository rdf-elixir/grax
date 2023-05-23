defmodule Grax.Schema.LinkProperty.UnionTest do
  use Grax.TestCase

  alias Grax.Schema.LinkProperty.Union
  alias Grax.InvalidResourceTypeError
  alias Grax.Schema.TypeError

  alias Example.{
    User,
    Post,
    Comment,
    ParentSchema,
    AnotherParentSchema,
    ChildSchema,
    ChildSchemaWithClass,
    ChildOfMany
  }

  defmodule PolymorphicUnionLinks do
    use Grax.Schema

    schema do
      property name: EX.name()

      link one: EX.one(),
           type: %{
             EX.Post => Post,
             EX.Comment => Comment,
             EX.ParentSchema => ParentSchema,
             EX.Child => ChildSchemaWithClass,
             EX.Child2 => ChildSchemaWithClass
           }

      link strict_one: EX.strictOne(),
           type: %{
             EX.Post => Post,
             EX.Comment => Comment,
             EX.ParentSchema => ParentSchema
           },
           on_rdf_type_mismatch: :error

      link many: EX.many(),
           type:
             list_of(%{
               nil => Post,
               EX.Comment => Comment,
               EX.ParentSchema => ParentSchema,
               EX.Child => ChildSchemaWithClass,
               EX.Child2 => ChildSchemaWithClass
             })
    end
  end

  defmodule NonPolymorphicUnionLinks do
    use Grax.Schema

    schema do
      property name: EX.name()

      link one: EX.one(),
           type: %{
             EX.Post => Post,
             EX.Comment => Comment,
             EX.ParentSchema => ParentSchema,
             EX.ChildSchema => ChildSchema,
             EX.ChildSchemaWithClass => ChildSchemaWithClass,
             EX.ChildOfMany => ChildOfMany
           },
           polymorphic: false,
           on_rdf_type_mismatch: :error

      link strict_one: EX.strictOne(),
           type: %{
             EX.Post => Post,
             EX.Comment => Comment,
             EX.ParentSchema => ParentSchema,
             EX.Child => ChildSchemaWithClass,
             EX.Child2 => ChildSchemaWithClass
           },
           polymorphic: false,
           on_rdf_type_mismatch: :error

      link many: EX.many(),
           type:
             list_of(%{
               nil => Post,
               EX.Comment => Comment,
               EX.ParentSchema => ParentSchema,
               EX.Child => ChildSchemaWithClass,
               EX.Child2 => ChildSchemaWithClass
             }),
           polymorphic: false
    end
  end

  defmodule UnionLinksShortForm do
    use Grax.Schema

    schema do
      property name: EX.name()

      link link: EX.link(), type: [Post, Comment]
      link inverse_link: -EX.inverseLink(), type: [Post, Comment]
    end
  end

  test "using the short-form when no class is defined causes an error" do
    assert_raise RuntimeError,
                 "invalid union type definition: Example.Untyped does not specify a class",
                 fn ->
                   defmodule UnionLinksShortFormFailure do
                     use Grax.Schema

                     schema do
                       property name: EX.name()

                       link link: EX.link(), type: [Example.Untyped, Example.Datatypes]
                     end
                   end
                 end
  end

  @tag skip: "TODO: support for polymorphic union links"
  test "inherited schemas within a union link cause an error" do
    assert_raise RuntimeError,
                 "invalid union type definition: union type on polymorphic link contains inherited schemas",
                 fn ->
                   defmodule PolymorphicUnionLinkWithInheritedSchemas do
                     use Grax.Schema

                     schema do
                       property name: EX.name()

                       link one: EX.one(),
                            type: %{
                              EX.ParentSchema => ParentSchema,
                              EX.ChildSchema => ChildSchema,
                              EX.ChildSchemaWithClass => ChildSchemaWithClass,
                              EX.ChildOfMany => ChildOfMany
                            }
                     end
                   end
                 end
  end

  describe "put/3" do
    test "with IRI" do
      assert PolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.bar(),
               strict_one: EX.bar(),
               many: [EX.baz1(), EX.baz2()]
             ) ==
               {:ok,
                %PolymorphicUnionLinks{
                  __id__: IRI.new(EX.Foo),
                  one: EX.bar(),
                  strict_one: EX.bar(),
                  many: [EX.baz1(), EX.baz2()]
                }}

      assert NonPolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.bar(),
               strict_one: EX.bar(),
               many: [EX.baz1(), EX.baz2()]
             ) ==
               {:ok,
                %NonPolymorphicUnionLinks{
                  __id__: IRI.new(EX.Foo),
                  one: EX.bar(),
                  strict_one: EX.bar(),
                  many: [EX.baz1(), EX.baz2()]
                }}
    end

    test "with bnode" do
      assert PolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(
               one: RDF.bnode("bar"),
               strict_one: RDF.bnode("bar"),
               many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
             ) ==
               {:ok,
                %PolymorphicUnionLinks{
                  __id__: IRI.new(EX.Foo),
                  one: RDF.bnode("bar"),
                  strict_one: RDF.bnode("bar"),
                  many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
                }}

      assert NonPolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(
               one: RDF.bnode("bar"),
               strict_one: RDF.bnode("bar"),
               many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
             ) ==
               {:ok,
                %NonPolymorphicUnionLinks{
                  __id__: IRI.new(EX.Foo),
                  one: RDF.bnode("bar"),
                  strict_one: RDF.bnode("bar"),
                  many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
                }}
    end

    test "with vocabulary namespace term" do
      assert PolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.Bar,
               strict_one: EX.Bar,
               many: [EX.baz(), EX.Baz1, EX.Baz2]
             ) ==
               {:ok,
                %PolymorphicUnionLinks{
                  __id__: IRI.new(EX.Foo),
                  one: IRI.new(EX.Bar),
                  strict_one: IRI.new(EX.Bar),
                  many: [EX.baz(), IRI.new(EX.Baz1), IRI.new(EX.Baz2)]
                }}

      assert NonPolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.Bar,
               strict_one: EX.Bar,
               many: [EX.baz(), EX.Baz1, EX.Baz2]
             ) ==
               {:ok,
                %NonPolymorphicUnionLinks{
                  __id__: IRI.new(EX.Foo),
                  one: IRI.new(EX.Bar),
                  strict_one: IRI.new(EX.Bar),
                  many: [EX.baz(), IRI.new(EX.Baz1), IRI.new(EX.Baz2)]
                }}
    end

    test "with matching schema" do
      assert PolymorphicUnionLinks.build!(EX.A)
             |> Grax.put(
               one: Comment.build!(EX.B),
               strict_one: ChildSchemaWithClass.build!(EX.B),
               many: [
                 Post.build!(EX.B),
                 Comment.build!(EX.C),
                 ParentSchema.build!(EX.D),
                 ChildSchemaWithClass.build!(EX.E)
               ]
             ) ==
               {:ok,
                %PolymorphicUnionLinks{
                  __id__: IRI.new(EX.A),
                  one: Comment.build!(EX.B),
                  strict_one: ChildSchemaWithClass.build!(EX.B),
                  many: [
                    Post.build!(EX.B),
                    Comment.build!(EX.C),
                    ParentSchema.build!(EX.D),
                    ChildSchemaWithClass.build!(EX.E)
                  ]
                }}

      assert NonPolymorphicUnionLinks.build!(EX.A)
             |> Grax.put(
               one: ChildSchema.build!(EX.B),
               strict_one: ChildSchemaWithClass.build!(EX.B),
               many: [
                 Post.build!(EX.B),
                 Comment.build!(EX.C),
                 ParentSchema.build!(EX.D),
                 ChildSchemaWithClass.build!(EX.E)
               ]
             ) ==
               {:ok,
                %NonPolymorphicUnionLinks{
                  __id__: IRI.new(EX.A),
                  one: ChildSchema.build!(EX.B),
                  strict_one: ChildSchemaWithClass.build!(EX.B),
                  many: [
                    Post.build!(EX.B),
                    Comment.build!(EX.C),
                    ParentSchema.build!(EX.D),
                    ChildSchemaWithClass.build!(EX.E)
                  ]
                }}
    end

    test "with non-matching schema" do
      assert PolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(:one, [User.build!(EX.Bar)]) ==
               {:error,
                TypeError.exception(
                  value: User.build!(EX.Bar),
                  type: %Union{
                    types: %{
                      RDF.iri(EX.Comment) => Comment,
                      RDF.iri(EX.Post) => Post,
                      RDF.iri(EX.ParentSchema) => ParentSchema,
                      RDF.iri(EX.Child) => ChildSchemaWithClass,
                      RDF.iri(EX.Child2) => ChildSchemaWithClass
                    }
                  }
                )}

      assert PolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(:strict_one, AnotherParentSchema.build!(EX.Bar)) ==
               {:error,
                TypeError.exception(
                  value: AnotherParentSchema.build!(EX.Bar),
                  type: %Union{
                    types: %{
                      RDF.iri(EX.Comment) => Comment,
                      RDF.iri(EX.Post) => Post,
                      RDF.iri(EX.ParentSchema) => ParentSchema
                    }
                  }
                )}

      assert NonPolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(:strict_one, User.build!(EX.Bar)) ==
               {:error,
                TypeError.exception(
                  value: User.build!(EX.Bar),
                  type: %Union{
                    types: %{
                      RDF.iri(EX.Comment) => Comment,
                      RDF.iri(EX.Post) => Post,
                      RDF.iri(EX.ParentSchema) => ParentSchema,
                      RDF.iri(EX.Child) => ChildSchemaWithClass,
                      RDF.iri(EX.Child2) => ChildSchemaWithClass
                    }
                  }
                )}

      assert NonPolymorphicUnionLinks.build!(EX.Foo)
             |> Grax.put(:many, [ChildOfMany.build!(EX.Bar)]) ==
               {:error,
                TypeError.exception(
                  value: ChildOfMany.build!(EX.Bar),
                  type: %Union{
                    types: %{
                      nil => Post,
                      RDF.iri(EX.Comment) => Comment,
                      RDF.iri(EX.ParentSchema) => ParentSchema,
                      RDF.iri(EX.Child) => ChildSchemaWithClass,
                      RDF.iri(EX.Child2) => ChildSchemaWithClass
                    }
                  }
                )}
    end

    test "with a map for a union link property" do
      assert_raise ArgumentError,
                   ~r/unable to determine value type of union link property/,
                   fn ->
                     PolymorphicUnionLinks.build!(EX.Foo)
                     |> Grax.put(:one, %{title: "foo"})
                   end
    end

    test "polymorphic link with inherited schema" do
      assert PolymorphicUnionLinks.build!(EX.A)
             |> Grax.put(
               one: ChildOfMany.build!(EX.B),
               strict_one: ChildSchemaWithClass.build!(EX.B),
               many: [ChildSchemaWithClass.build!(EX.B), ChildOfMany.build!(EX.C)]
             ) ==
               {:ok,
                %PolymorphicUnionLinks{
                  __id__: IRI.new(EX.A),
                  one: ChildOfMany.build!(EX.B),
                  strict_one: ChildSchemaWithClass.build!(EX.B),
                  many: [ChildSchemaWithClass.build!(EX.B), ChildOfMany.build!(EX.C)]
                }}
    end

    test "non-polymorphic property with inherited schema" do
      assert NonPolymorphicUnionLinks.build!(EX.A)
             |> Grax.put(:strict_one, ChildSchema.build!(EX.B)) ==
               {:error,
                TypeError.exception(
                  value: ChildSchema.build!(EX.B),
                  type: %Union{
                    types: %{
                      RDF.iri(EX.Child) => ChildSchemaWithClass,
                      RDF.iri(EX.Child2) => ChildSchemaWithClass,
                      RDF.iri(EX.Comment) => Comment,
                      RDF.iri(EX.ParentSchema) => ParentSchema,
                      RDF.iri(EX.Post) => Post
                    }
                  }
                )}

      assert NonPolymorphicUnionLinks.build!(EX.A)
             |> Grax.put(:many, [ChildSchema.build!(EX.B)]) ==
               {:error,
                TypeError.exception(
                  value: ChildSchema.build!(EX.B),
                  type: %Union{
                    types: %{
                      RDF.iri(EX.Child) => ChildSchemaWithClass,
                      RDF.iri(EX.Child2) => ChildSchemaWithClass,
                      RDF.iri(EX.Comment) => Comment,
                      RDF.iri(EX.ParentSchema) => ParentSchema,
                      nil => Post
                    }
                  }
                )}
    end
  end

  describe "preloading union links (general)" do
    test "resource typed with element of the union" do
      assert RDF.graph([
               EX.A
               |> EX.one(EX.Post1)
               |> EX.strictOne(EX.Post1)
               |> EX.many([EX.Post1, EX.Comment1]),
               EX.Post1 |> RDF.type(EX.Post) |> EX.title("foo"),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A,
                 one:
                   Post.build!(EX.Post1,
                     title: "foo",
                     slug: "foo",
                     __additional_statements__: %{RDF.type() => EX.Post}
                   ),
                 strict_one:
                   Post.build!(EX.Post1,
                     title: "foo",
                     slug: "foo",
                     __additional_statements__: %{RDF.type() => EX.Post}
                   ),
                 many: [
                   Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   ),
                   Post.build!(EX.Post1,
                     title: "foo",
                     slug: "foo",
                     __additional_statements__: %{RDF.type() => EX.Post}
                   )
                 ]
               )
    end

    test "fallback" do
      assert RDF.graph([
               EX.A |> EX.many(EX.Post1),
               EX.Post1 |> EX.title("foo")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [Post.build!(EX.Post1, title: "foo", slug: "foo")]
               )

      assert RDF.graph([
               EX.A |> EX.many(EX.Post1, EX.Comment1),
               EX.Post1 |> RDF.type(EX.Other) |> EX.title("foo"),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [
                   Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   ),
                   Post.build!(EX.Post1,
                     title: "foo",
                     slug: "foo",
                     __additional_statements__: %{RDF.type() => [EX.Other, EX.Post]}
                   )
                 ]
               )
    end

    test "when no values present" do
      assert RDF.graph([EX.A |> EX.name("nothing")])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A, name: "nothing")
    end

    test "when no values present in a nested schema struct with union links" do
      defmodule NestedPolymorphicUnionLinks do
        use Grax.Schema

        schema do
          link foo: EX.foo(), type: PolymorphicUnionLinks
        end
      end

      assert RDF.graph([EX.A |> EX.foo(EX.B)])
             |> NestedPolymorphicUnionLinks.load(EX.A) ==
               NestedPolymorphicUnionLinks.build(EX.A,
                 foo: PolymorphicUnionLinks.build!(RDF.iri(EX.B))
               )
    end

    test "union link defined in short-form" do
      assert RDF.graph([
               EX.A |> EX.link(EX.Comment1),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> UnionLinksShortForm.load(EX.A) ==
               UnionLinksShortForm.build(EX.A,
                 link: [
                   Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   )
                 ]
               )
    end

    test "union links on inverses" do
      assert RDF.graph([
               EX.Comment1
               |> RDF.type(EX.Comment)
               |> EX.inverseLink(EX.A)
             ])
             |> UnionLinksShortForm.load(EX.A) ==
               UnionLinksShortForm.build(EX.A,
                 inverse_link: [
                   Comment.build!(EX.Comment1,
                     __additional_statements__: %{
                       RDF.type() => EX.Comment,
                       EX.inverseLink() => EX.A
                     }
                   )
                 ]
               )
    end
  end

  describe "preloading polymorphic union links" do
    @tag skip: "TODO: support for polymorphic union links"
    test "selects most specific schema inherited by any of schemas of the union" do
      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B |> RDF.type([EX.ChildSchema])
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A,
                 one:
                   ChildSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.ParentSchema, EX.ChildSchema]},
                     f2: :foo
                   )
               )
    end

    @tag skip: "TODO: support for polymorphic union links"
    test "selects most specific schema inherited by any of schemas of the union even when types directly matching a union schema are present" do
    end

    @tag skip: "TODO: support for polymorphic union links"
    test "returns error when multiple inherited schemas are matching" do
    end

    test "returns error when multiple independent classes are matching" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Post1),
               EX.Post1 |> RDF.type([EX.Post, EX.Comment]) |> EX.title("foo")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [Post, Comment]
                )}

      assert RDF.graph([
               EX.A |> EX.strictOne(EX.Post1),
               EX.Post1 |> RDF.type([EX.Post, EX.Comment]) |> EX.title("foo")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [Post, Comment]
                )}
    end

    test "ignores resources when no class matches with on_rdf_type_mismatch: :ignore" do
      # when no class matches
      assert RDF.graph([
               EX.A |> EX.one(EX.Something)
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A)

      assert RDF.graph([
               EX.A |> EX.one(EX.Something1) |> EX.one(EX.Something21),
               EX.Something1 |> EX.foo("foo"),
               EX.Something2 |> RDF.type(EX.Other) |> EX.bar("bar")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A)

      # when some classes don't match
      assert RDF.graph([
               EX.A |> EX.one(EX.Something1) |> EX.one(EX.Comment1),
               EX.Something1 |> EX.foo("foo"),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("bar")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               PolymorphicUnionLinks.build(EX.A,
                 one:
                   Comment.build!(EX.Comment1,
                     content: "bar",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   )
               )
    end

    test "returns error when no class matches with on_rdf_type_mismatch: :error" do
      assert RDF.graph([
               EX.A |> EX.strictOne(EX.Post1),
               EX.Post1 |> EX.title("foo")
             ])
             |> PolymorphicUnionLinks.load(EX.A) ==
               {:error, InvalidResourceTypeError.exception(type: :no_match, resource_types: [])}
    end
  end

  describe "preloading non-polymorphic union links" do
    test "select most specific schema from union" do
      # resource typed with multiple classes which are related via inheritance
      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B |> RDF.type([EX.ParentSchema, EX.ChildSchema])
             ])
             |> NonPolymorphicUnionLinks.load(EX.A) ==
               NonPolymorphicUnionLinks.build(EX.A,
                 one:
                   ChildSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.ParentSchema, EX.ChildSchema]},
                     f2: :foo
                   )
               )

      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B
               |> RDF.type([
                 EX.ParentSchema,
                 EX.ChildSchemaWithClass,
                 EX.ChildOfMany
               ])
             ])
             |> NonPolymorphicUnionLinks.load(EX.A) ==
               NonPolymorphicUnionLinks.build(EX.A,
                 one:
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
    end

    test "returns error when most specific schema is not unique due to multiple inheritance" do
      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B
               |> RDF.type([
                 EX.ParentSchema,
                 EX.ChildSchema,
                 EX.ChildSchemaWithClass,
                 EX.ChildOfMany
               ])
             ])
             |> NonPolymorphicUnionLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [ChildSchema, ChildOfMany]
                )}
    end

    @tag skip: "TODO: support for polymorphic union links"
    test "fall back to lowest common ancestor in union" do
      # resource typed with inherited schema class where a unique parent is part of the union
      assert RDF.graph([
               EX.A |> EX.many(EX.B) |> EX.strictOne(EX.C),
               EX.B |> RDF.type(EX.ChildOfMany),
               EX.C |> RDF.type(EX.ChildOfMany)
             ])
             |> NonPolymorphicUnionLinks.load(EX.A) ==
               NonPolymorphicUnionLinks.build(EX.A,
                 strict_one:
                   ChildSchemaWithClass.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.Parent2, EX.SubClass]}
                   ),
                 many:
                   ChildSchemaWithClass.build!(EX.C,
                     __additional_statements__: %{RDF.type() => [EX.Parent2, EX.SubClass]}
                   )
               )
    end

    @tag skip: "TODO: support for polymorphic union links"
    test "returns error when lowest common ancestor in union is not unique" do
      # resource typed with inherited schema class where multiple parents are part of the union
    end
  end
end
