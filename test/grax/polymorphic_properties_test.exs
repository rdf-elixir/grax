defmodule Grax.PolymorphicPropertiesTest do
  use Grax.TestCase

  alias Grax.InvalidResourceTypeError
  alias Grax.Schema.TypeError

  defmodule PolymorphicLinks do
    use Grax.Schema

    schema do
      property name: EX.name()

      link one: EX.one(),
           type: %{
             EX.Post => Example.Post,
             EX.Comment => Example.Comment
           }

      link strict_one: EX.strictOne(),
           type: %{
             EX.Post => Example.Post,
             EX.Comment => Example.Comment
           },
           on_type_mismatch: :error

      link many: EX.many(),
           type:
             list_of(%{
               nil => Example.Post,
               EX.Comment => Example.Comment
             })
    end
  end

  defmodule PolymorphicLinkWithInheritance do
    use Grax.Schema

    schema do
      property name: EX.name()

      link linked: EX.linked(),
           type: %{
             EX.ParentSchema => Example.ParentSchema,
             EX.ChildSchema => Example.ChildSchema,
             EX.ChildSchemaWithClass => Example.ChildSchemaWithClass,
             EX.ChildOfMany => Example.ChildOfMany
           },
           on_type_mismatch: :error
    end
  end

  defmodule PolymorphicLinksShortForm do
    use Grax.Schema

    schema do
      property name: EX.name()

      link link: EX.link(), type: [Example.Post, Example.Comment]
      link inverse_link: -EX.inverseLink(), type: [Example.Post, Example.Comment]
    end
  end

  test "using the short-form when no class is defined leads to a proper error" do
    assert_raise RuntimeError,
                 "invalid polymorphic type definition: Example.Untyped does not specify a class",
                 fn ->
                   defmodule PolymorphicLinksShortFormFailure do
                     use Grax.Schema

                     schema do
                       property name: EX.name()

                       link link: EX.link(), type: [Example.Untyped, Example.Datatypes]
                     end
                   end
                 end
  end

  describe "put/3" do
    test "a RDF.IRI on a link property" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.bar(),
               strict_one: EX.bar(),
               many: [EX.baz1(), EX.baz2()]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: EX.bar(),
                  strict_one: EX.bar(),
                  many: [EX.baz1(), EX.baz2()]
                }}
    end

    test "a RDF.BlankNode on a link property" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: RDF.bnode("bar"),
               strict_one: RDF.bnode("bar"),
               many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: RDF.bnode("bar"),
                  strict_one: RDF.bnode("bar"),
                  many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
                }}
    end

    test "a vocabulary namespace term on a link property" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.Bar,
               strict_one: EX.Bar,
               many: [EX.baz(), EX.Baz1, EX.Baz2]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: IRI.new(EX.Bar),
                  strict_one: IRI.new(EX.Bar),
                  many: [EX.baz(), IRI.new(EX.Baz1), IRI.new(EX.Baz2)]
                }}
    end

    test "a Grax schema struct of the proper type" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.Bar,
               strict_one: EX.Bar,
               many: [EX.baz(), EX.Baz1, EX.Baz2]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: IRI.new(EX.Bar),
                  strict_one: IRI.new(EX.Bar),
                  many: [EX.baz(), IRI.new(EX.Baz1), IRI.new(EX.Baz2)]
                }}
    end

    test "a Grax schema struct with a wrong type on a strict link" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(:strict_one, Example.User.build!(EX.Bar)) ==
               {:error,
                TypeError.exception(
                  value: Example.User.build!(EX.Bar),
                  type: %Grax.Schema.Property.Polymorphic{
                    types: %{
                      RDF.iri(EX.Comment) => Example.Comment,
                      RDF.iri(EX.Post) => Example.Post
                    }
                  }
                )}
    end

    test "with a map for a polymorphic property" do
      assert_raise ArgumentError,
                   ~r/unable to determine value type of polymorphic property/,
                   fn ->
                     PolymorphicLinks.build!(EX.Foo)
                     |> Grax.put(:one, %{title: "foo"})
                   end
    end
  end

  describe "preloading" do
    test "when a class matches" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Post1) |> EX.strictOne(EX.Post1),
               EX.Post1 |> RDF.type(EX.Post) |> EX.title("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one:
                   Example.Post.build!(EX.Post1,
                     title: "foo",
                     slug: "foo",
                     __additional_statements__: %{RDF.type() => EX.Post}
                   ),
                 strict_one:
                   Example.Post.build!(EX.Post1,
                     title: "foo",
                     slug: "foo",
                     __additional_statements__: %{RDF.type() => EX.Post}
                   ),
                 many: []
               )

      assert RDF.graph([
               EX.A |> EX.one(EX.Comment1) |> EX.strictOne(EX.Comment1),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one:
                   Example.Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   ),
                 strict_one:
                   Example.Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   ),
                 many: []
               )

      assert RDF.graph([
               EX.A |> EX.many(EX.Comment1),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [
                   Example.Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   )
                 ]
               )
    end

    test "polymorphic links on inverses" do
      assert RDF.graph([
               EX.Comment1
               |> RDF.type(EX.Comment)
               |> EX.inverseLink(EX.A)
             ])
             |> PolymorphicLinksShortForm.load(EX.A) ==
               PolymorphicLinksShortForm.build(EX.A,
                 inverse_link: [
                   Example.Comment.build!(EX.Comment1,
                     __additional_statements__: %{
                       RDF.type() => EX.Comment,
                       EX.inverseLink() => EX.A
                     }
                   )
                 ]
               )
    end

    test "polymorphic link defined in short-form" do
      assert RDF.graph([
               EX.A |> EX.link(EX.Comment1),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> PolymorphicLinksShortForm.load(EX.A) ==
               PolymorphicLinksShortForm.build(EX.A,
                 link: [
                   Example.Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   )
                 ]
               )
    end

    test "fallback" do
      assert RDF.graph([
               EX.A |> EX.many(EX.Post1),
               EX.Post1 |> EX.title("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [Example.Post.build!(EX.Post1, title: "foo", slug: "foo")]
               )

      assert RDF.graph([
               EX.A |> EX.many(EX.Post1) |> EX.many(EX.Comment1),
               EX.Post1 |> RDF.type(EX.Other) |> EX.title("foo"),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [
                   Example.Comment.build!(EX.Comment1,
                     content: "foo",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   ),
                   Example.Post.build!(EX.Post1,
                     title: "foo",
                     slug: "foo",
                     __additional_statements__: %{RDF.type() => [EX.Other, EX.Post]}
                   )
                 ]
               )
    end

    test "when no class matches with non-strict matching" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Something)
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: []
               )

      assert RDF.graph([
               EX.A |> EX.one(EX.Something1) |> EX.one(EX.Something21),
               EX.Something1 |> EX.foo("foo"),
               EX.Something2 |> RDF.type(EX.Other) |> EX.bar("bar")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: []
               )
    end

    test "when some classes don't match with non-strict matching" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Something1) |> EX.one(EX.Comment1),
               EX.Something1 |> EX.foo("foo"),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("bar")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one:
                   Example.Comment.build!(EX.Comment1,
                     content: "bar",
                     __additional_statements__: %{RDF.type() => EX.Comment}
                   ),
                 strict_one: nil,
                 many: []
               )
    end

    test "when no class matches with strict matching" do
      assert RDF.graph([
               EX.A |> EX.strictOne(EX.Post1),
               EX.Post1 |> EX.title("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               {:error, InvalidResourceTypeError.exception(type: :no_match, resource_types: [])}
    end

    test "when multiple classes are matching which are related via inheritance" do
      assert RDF.graph([
               EX.A |> EX.linked(EX.B),
               EX.B |> RDF.type([EX.ParentSchema, EX.ChildSchema])
             ])
             |> PolymorphicLinkWithInheritance.load(EX.A) ==
               PolymorphicLinkWithInheritance.build(EX.A,
                 linked:
                   Example.ChildSchema.build!(EX.B,
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
                   Example.ChildOfMany.build!(EX.B,
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
                  resource_types: [Example.ChildSchema, Example.ChildOfMany]
                )}
    end

    test "when multiple independent classes are matching" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Post1),
               EX.Post1 |> RDF.type([EX.Post, EX.Comment]) |> EX.title("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [Example.Post, Example.Comment]
                )}

      assert RDF.graph([
               EX.A |> EX.strictOne(EX.Post1),
               EX.Post1 |> RDF.type([EX.Post, EX.Comment]) |> EX.title("foo")
             ])
             |> PolymorphicLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [Example.Post, Example.Comment]
                )}
    end

    test "when no values present" do
      assert RDF.graph([EX.A |> EX.name("nothing")])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A, name: "nothing")
    end

    test "when no values present in a nested schema struct with polymorphic links" do
      defmodule NestedPolymorphicLinks do
        use Grax.Schema

        schema do
          link foo: EX.foo(), type: PolymorphicLinks
        end
      end

      assert RDF.graph([EX.A |> EX.foo(EX.B)])
             |> NestedPolymorphicLinks.load(EX.A) ==
               NestedPolymorphicLinks.build(EX.A,
                 foo: PolymorphicLinks.build!(RDF.iri(EX.B))
               )
    end
  end
end
