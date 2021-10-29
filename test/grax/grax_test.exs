defmodule GraxTest do
  use Grax.TestCase

  doctest Grax

  import Grax.UuidTestHelper

  alias Grax.ValidationError
  alias Grax.Schema.{TypeError, InvalidProperty, CardinalityError}
  alias Example.IdSpecs

  describe "build/1" do
    test "with a string id" do
      assert Example.User.build("http://example.com/user/1") ==
               {:ok, %Example.User{__id__: IRI.new("http://example.com/user/1")}}
    end

    test "with a vocabulary namespace term" do
      assert Example.User.build(EX.User0) ==
               {:ok, %Example.User{__id__: IRI.new(EX.User0)}}
    end
  end

  describe "build with an explicitly given id" do
    test "with a map of valid property values" do
      assert Example.User.build(EX.User0, %{
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0)
             }) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  name: "Foo",
                  email: ["foo@example.com"],
                  password: "secret",
                  posts: [Example.post(depth: 0)]
                }}
    end

    test "with a keyword list of valid property values" do
      assert Example.User.build(EX.User0,
               name: "Foo",
               email: "foo@example.com",
               password: "secret",
               posts: Example.post(depth: 0)
             ) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  name: "Foo",
                  email: ["foo@example.com"],
                  password: "secret",
                  posts: [Example.post(depth: 0)]
                }}
    end

    test "with another Grax.Schema mapping of the same type" do
      assert Example.User.build(EX.Other, Example.user(EX.User0)) ==
               {:ok, %Example.User{Example.user(EX.User0) | __id__: RDF.iri(EX.Other)}}
    end

    test "with invalid property values" do
      assert Example.User.build(EX.User0,
               age: "secret",
               foo: "foo",
               posts: Example.User.build!(EX.Bar)
             ) ==
               {:error,
                %ValidationError{
                  context: RDF.iri(EX.User0),
                  errors: [
                    posts:
                      TypeError.exception(
                        value: Example.User.build!(EX.Bar),
                        type: {:resource, Example.Post}
                      ),
                    foo: InvalidProperty.exception(property: :foo),
                    age: TypeError.exception(value: "secret", type: XSD.Integer)
                  ]
                }}

      assert Example.User.build(EX.Other, Example.user(EX.User0) |> Map.put(:age, "secret")) ==
               {:error,
                %ValidationError{
                  context: RDF.iri(EX.Other),
                  errors: [
                    age: TypeError.exception(value: "secret", type: XSD.Integer)
                  ]
                }}
    end

    test "with __additional_statements__ map" do
      assert Example.User.build(EX.User0, %{
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0),
               __additional_statements__: %{
                 EX.P1 => EX.O1,
                 EX.P2 => "foo"
               }
             }) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  __additional_statements__: %{
                    RDF.iri(EX.P1) => MapSet.new([RDF.iri(EX.O1)]),
                    RDF.iri(EX.P2) => MapSet.new([~L"foo"])
                  },
                  name: "Foo",
                  email: ["foo@example.com"],
                  password: "secret",
                  posts: [Example.post(depth: 0)]
                }}
    end
  end

  describe "build with an explicitly given id as part of the initial data" do
    test "with a map containing an __id__ field" do
      assert Example.User.build(%{
               __id__: EX.User0,
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret"
             }) ==
               Example.User.build(EX.User0, %{
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret"
               })
    end
  end

  describe "build from an id schema" do
    test "when an explicitly given Id.Schema doesn't require anything" do
      assert {:ok, %Example.User{__id__: id}} =
               IdSpecs.GenericUuids.expected_id_schema(Example.User)
               |> Example.User.build()

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :hex)
    end

    test "when an explicitly given Id.Schema depends on a given property value" do
      id = RDF.iri("http://example.com/#{UUID.uuid5(:url, "foo@example.com")}")

      assert {:ok,
              %Example.User{
                __id__: ^id,
                name: "Foo",
                canonical_email: "foo@example.com"
              }} =
               IdSpecs.HashUuids.expected_id_schema(Example.User)
               |> Example.User.build(%{
                 name: "Foo",
                 canonical_email: "foo@example.com"
               })
    end

    test "when an explicitly given Id.Schema depends on a missing property value" do
      assert IdSpecs.HashUuids.expected_id_schema(Example.User)
             |> Example.User.build(%{name: "Foo"}) ==
               {:error, "no value for field :canonical_email for UUID name present"}
    end

    test "when schema is associated with an id schema it is used implicitly" do
      assert {:ok, %Example.WithIdSchema{__id__: id, foo: "Foo"}} =
               Example.WithIdSchema.build(%{foo: "Foo"})

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)

      assert {:ok, %Example.WithIdSchema{__id__: id, foo: "Foo"}} =
               Example.WithIdSchema.build(foo: "Foo")

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)
    end

    test "with nested ids to generate" do
      assert {:ok,
              %Example.WithIdSchemaNested{
                __id__: ~I<http://example.com/bar/bar1>,
                foo: %Example.WithIdSchema{__id__: nested_id},
                more: [
                  %Example.WithIdSchemaNested{
                    __id__: ~I<http://example.com/bar/bar2>,
                    foo: %Example.WithIdSchema{__id__: nested_id2}
                  }
                ]
              }} =
               Example.WithIdSchemaNested.build(
                 bar: "bar1",
                 foo: %{foo: "foo1"},
                 more: %{bar: "bar2", foo: %{foo: "foo2"}}
               )

      assert_valid_uuid(nested_id, "http://example.com/", version: 4, type: :default)
      assert_valid_uuid(nested_id2, "http://example.com/", version: 4, type: :default)
      refute nested_id == nested_id2
    end

    test "with a matching id schema associated with multiple schemas" do
      assert {:ok, %Example.MultipleSchemasA{__id__: ~I<http://example.com/FooA>, foo: "FooA"}} =
               Example.MultipleSchemasA.build(%{foo: "FooA"})

      assert {:ok, %Example.MultipleSchemasB{__id__: ~I<http://example.com/FooB>, foo: "FooB"}} =
               Example.MultipleSchemasB.build(%{foo: "FooB"})

      assert {:ok, %Example.VarMappingD{__id__: ~I<http://example.com/foo/FOOD>, name: "FooD"}} =
               Example.VarMappingD.build(%{name: "FooD"})
    end

    test "with matching custom selector" do
      assert {:ok,
              %Example.WithCustomSelectedIdSchemaA{
                __id__: ~I<http://example.com/foo/foo1>,
                foo: "foo1"
              }} = Example.WithCustomSelectedIdSchemaA.build(foo: "foo1")

      assert {:ok, %Example.WithCustomSelectedIdSchemaB{__id__: id, bar: "bar"}} =
               Example.WithCustomSelectedIdSchemaB.build(bar: "bar")

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)

      assert {:ok, %Example.WithCustomSelectedIdSchemaB{__id__: id, bar: "test"}} =
               Example.WithCustomSelectedIdSchemaB.build(bar: "test")

      assert_valid_uuid(id, "http://example.com/", version: 5, type: :default)
    end

    test "with non-matching custom selector" do
      assert Example.WithCustomSelectedIdSchemaB.build(bar: "") ==
               {:error, "no id schema found"}
    end

    test "Id.BlankNode as a Id.Schema" do
      assert {:ok, %Example.WithBlankNodeIdSchema{__id__: %RDF.BlankNode{}}} =
               IdSpecs.BlankNodes.expected_id_schema(Example.WithBlankNodeIdSchema)
               |> Example.WithBlankNodeIdSchema.build()

      assert {:ok, %Example.WithBlankNodeIdSchema{__id__: %RDF.BlankNode{}, name: "Foo"}} =
               Example.WithBlankNodeIdSchema.build(%{name: "Foo"})

      assert {:ok, %Example.WithBlankNodeIdSchema{__id__: %RDF.BlankNode{} = id1, name: "Foo"}} =
               Example.WithBlankNodeIdSchema.build(name: "Foo")

      assert {:ok, %Example.WithBlankNodeIdSchema{__id__: %RDF.BlankNode{} = id2}} =
               Example.WithBlankNodeIdSchema.build(name: "Foo")

      assert id1 != id2
    end
  end

  describe "build!/1" do
    test "with a map containing an __id__ field" do
      assert Example.User.build!(%{
               __id__: EX.User0,
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret"
             }) ==
               Example.User.build!(EX.User0, %{
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret"
               })
    end
  end

  describe "build!/2" do
    test "with a map of valid property values" do
      assert Example.User.build!(EX.User0, %{
               name: "Foo",
               email: "foo@example.com",
               password: "secret",
               posts: Example.post(depth: 0)
             }) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret",
                 posts: [Example.post(depth: 0)]
               }
    end

    test "with a keyword list of valid property values" do
      assert Example.User.build!(EX.User0,
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0)
             ) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret",
                 posts: [Example.post(depth: 0)]
               }
    end

    test "duplicate values are removed" do
      assert Example.User.build!(EX.User0,
               name: ["Foo", "Foo"],
               email: ["foo@example.com", "foo@example.com"]
             ) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo",
                 email: ["foo@example.com"]
               }
    end

    test "with another Grax.Schema mapping of the same type" do
      assert Example.User.build!(EX.Other, Example.user(EX.User0)) ==
               %Example.User{Example.user(EX.User0) | __id__: RDF.iri(EX.Other)}
    end

    test "with __additional_statements__ map" do
      assert Example.User.build!(EX.User0, %{
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0),
               __additional_statements__: %{
                 EX.P1 => EX.O1,
                 EX.P2 => "foo"
               }
             }) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 __additional_statements__: %{
                   RDF.iri(EX.P1) => MapSet.new([RDF.iri(EX.O1)]),
                   RDF.iri(EX.P2) => MapSet.new([~L"foo"])
                 },
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret",
                 posts: [Example.post(depth: 0)]
               }
    end

    test "with invalid property values" do
      assert Example.User.build!(EX.User0,
               name: "Foo",
               age: "secret",
               posts: Example.user(EX.User0)
             ) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo",
                 age: "secret",
                 posts: [Example.user(EX.User0)]
               }

      assert Example.User.build!(EX.Other, Example.user(EX.User0) |> Map.put(:age, "secret")) ==
               %Example.User{
                 (Example.user(EX.User0)
                  |> Map.put(:age, "secret"))
                 | __id__: RDF.iri(EX.Other)
               }
    end
  end

  describe "id/2" do
    test "with a map containing an __id__ field" do
      assert {:ok, RDF.iri(EX.Foo)} ==
               Example.User.__id__(%{
                 __id__: RDF.iri(EX.Foo),
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret"
               })

      assert {:ok, RDF.iri(EX.Foo)} ==
               Example.User.__id__(%{
                 __id__: EX.Foo,
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret"
               })

      assert {:ok, ~B"foo"} == Example.User.__id__(%{__id__: ~B"foo"})
      assert {:ok, RDF.iri(EX.User0)} == Example.user(EX.User0) |> Example.User.__id__()
    end

    test "when an id schema exists" do
      assert {:ok, id} = Example.WithIdSchema.__id__(%{foo: "Foo"})
      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)

      assert {:ok, id} = Example.WithIdSchema.__id__(foo: "Foo")
      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)

      assert {:ok, ~I<http://example.com/foo/FOO>} = Example.VarMappingA.__id__(name: "Foo")

      assert {:ok, ~I<http://example.com/feab40e1fca77c7360ccca1481bb8ba5f919ce3a>} =
               Example.VarMappingC.__id__(name: "Foo")
    end
  end

  describe "put/3" do
    test "when the property exists and the value type matches the schema" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:name, "Foo") ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  name: "Foo"
                }}

      assert Example.IdsAsPropertyValues.build!(EX.S)
             |> Grax.put!(:iri, EX.foo()) ==
               %Example.IdsAsPropertyValues{
                 __id__: IRI.new(EX.S),
                 iri: EX.foo()
               }

      assert Example.User.build!(EX.User0)
             |> Grax.put(:email, ["foo@example.com"]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  email: ["foo@example.com"]
                }}
    end

    test "when the property does not exist" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:foo, "foo") ==
               {:error, InvalidProperty.exception(property: :foo)}
    end

    test "when the value type does not match the schema" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:age, "secret") ==
               {:error, TypeError.exception(value: "secret", type: XSD.Integer)}

      assert Example.IdsAsPropertyValues.build!(EX.S)
             |> Grax.put(:iri, "foo") ==
               {:error, TypeError.exception(value: "foo", type: RDF.IRI)}

      assert Example.Required.build!(EX.Foo)
             |> Grax.put(:foo, nil) ==
               {:error, CardinalityError.exception(cardinality: 1, value: nil)}
    end

    test "scalar values on a set property" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:email, "foo@example.com") ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  email: ["foo@example.com"]
                }}
    end

    test "a single value in a list on a scalar property" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:name, ["foo"]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  name: "foo"
                }}
    end

    test "a vocabulary namespace term on an IRI property" do
      assert Example.IdsAsPropertyValues.build!(EX.Foo)
             |> Grax.put(:iri, EX.Bar) ==
               {:ok,
                %Example.IdsAsPropertyValues{
                  __id__: IRI.new(EX.Foo),
                  iri: IRI.new(EX.Bar)
                }}

      assert Example.IdsAsPropertyValues.build!(EX.Foo)
             |> Grax.put(:iris, [EX.Bar, EX.Baz]) ==
               {:ok,
                %Example.IdsAsPropertyValues{
                  __id__: IRI.new(EX.Foo),
                  iris: [IRI.new(EX.Bar), IRI.new(EX.Baz)]
                }}
    end

    test "previous values are overwritten" do
      assert Example.user(EX.User0)
             |> Grax.put(:name, "Foo") ==
               {:ok, %Example.User{Example.user(EX.User0) | name: "Foo"}}

      assert Example.user(EX.User0)
             |> Grax.put(:email, ["foo@example.com"]) ==
               {:ok, %Example.User{Example.user(EX.User0) | email: ["foo@example.com"]}}
    end

    test "duplicate values are removed" do
      assert Example.user(EX.User0)
             |> Grax.put(:email, ["foo@example.com", "foo@example.com"]) ==
               {:ok, %Example.User{Example.user(EX.User0) | email: ["foo@example.com"]}}

      assert Example.user(EX.User0)
             |> Grax.put(:name, ["Foo", "Foo"]) ==
               {:ok, %Example.User{Example.user(EX.User0) | name: "Foo"}}
    end

    test "with virtual properties" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:password, "secret") ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  password: "secret"
                }}
    end

    test "with the __id__ field" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:__id__, "foo") ==
               {:error,
                InvalidProperty.exception(
                  property: :__id__,
                  message:
                    "__id__ can't be changed. Use build/2 to construct a new Grax.Schema mapping from another with a new id."
                )}
    end

    test "with a link property and a proper Grax.Schema struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put(:next, Example.SelfLinked.build!(EX.Bar)) ==
               {:ok,
                %Example.SelfLinked{
                  __id__: IRI.new(EX.Foo),
                  next: Example.SelfLinked.build!(EX.Bar)
                }}

      assert Example.User.build!(EX.User0)
             |> Grax.put(:posts, [Example.post(depth: 0)]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  posts: [Example.post(depth: 0)]
                }}

      assert Example.User.build!(EX.User0)
             |> Grax.put(:posts, Example.post(depth: 0)) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  posts: [Example.post(depth: 0)]
                }}
    end

    test "a RDF.IRI on a link property" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put(:next, EX.bar()) ==
               {:ok,
                %Example.SelfLinked{
                  __id__: IRI.new(EX.Foo),
                  next: IRI.new(EX.bar())
                }}

      assert Example.User.build!(EX.User0)
             |> Grax.put(:posts, [RDF.iri(EX.Foo), RDF.iri(EX.Bar)]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  posts: [IRI.new(EX.Foo), IRI.new(EX.Bar)]
                }}

      assert Example.HeterogeneousLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.bar(),
               strict_one: EX.bar(),
               many: [EX.baz1(), EX.baz2()]
             ) ==
               {:ok,
                %Example.HeterogeneousLinks{
                  __id__: IRI.new(EX.Foo),
                  one: EX.bar(),
                  strict_one: EX.bar(),
                  many: [EX.baz1(), EX.baz2()]
                }}
    end

    test "a RDF.BlankNode on a link property" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put(:next, RDF.bnode("bar")) ==
               {:ok,
                %Example.SelfLinked{
                  __id__: IRI.new(EX.Foo),
                  next: RDF.bnode("bar")
                }}

      assert Example.User.build!(EX.User0)
             |> Grax.put(:posts, [RDF.bnode("bar"), RDF.bnode("baz")]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  posts: [
                    RDF.bnode("bar"),
                    RDF.bnode("baz")
                  ]
                }}

      assert Example.HeterogeneousLinks.build!(EX.Foo)
             |> Grax.put(
               one: RDF.bnode("bar"),
               strict_one: RDF.bnode("bar"),
               many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
             ) ==
               {:ok,
                %Example.HeterogeneousLinks{
                  __id__: IRI.new(EX.Foo),
                  one: RDF.bnode("bar"),
                  strict_one: RDF.bnode("bar"),
                  many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
                }}
    end

    test "a vocabulary namespace term on a link property" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put(:next, EX.Bar) ==
               {:ok,
                %Example.SelfLinked{
                  __id__: IRI.new(EX.Foo),
                  next: RDF.iri(EX.Bar)
                }}

      assert Example.User.build!(EX.User0)
             |> Grax.put(:posts, [EX.Foo, EX.Bar]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  posts: [IRI.new(EX.Foo), IRI.new(EX.Bar)]
                }}

      assert Example.HeterogeneousLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.Bar,
               strict_one: EX.Bar,
               many: [EX.baz(), EX.Baz1, EX.Baz2]
             ) ==
               {:ok,
                %Example.HeterogeneousLinks{
                  __id__: IRI.new(EX.Foo),
                  one: IRI.new(EX.Bar),
                  strict_one: IRI.new(EX.Bar),
                  many: [EX.baz(), IRI.new(EX.Baz1), IRI.new(EX.Baz2)]
                }}
    end

    test "with a simple map with the __id__ field" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put(:next, %{__id__: RDF.iri(EX.Bar)}) ==
               {:ok,
                %Example.SelfLinked{
                  __id__: IRI.new(EX.Foo),
                  next: Example.SelfLinked.build!(EX.Bar)
                }}
    end

    test "with a map and an id schema defined for the linked schema" do
      assert {:ok,
              %Example.WithIdSchemaNested{
                __id__: ~I<http://example.com/bar/bar1>,
                foo: %Example.WithIdSchema{__id__: nested_id}
              }} =
               Example.WithIdSchemaNested.build!(bar: "bar1")
               |> Grax.put(foo: %{foo: "foo1"})

      assert_valid_uuid(nested_id, "http://example.com/", version: 4, type: :default)
    end

    test "with a list of maps" do
      assert {:ok,
              %Example.WithIdSchemaNested{
                __id__: ~I<http://example.com/bar/bar1>,
                more: [
                  %Example.WithIdSchemaNested{
                    __id__: ~I<http://example.com/bar/bar1>,
                    bar: "bar1"
                  },
                  %Example.WithIdSchemaNested{
                    __id__: ~I<http://example.com/bar/bar2>,
                    bar: "bar2"
                  }
                ]
              }} =
               Example.WithIdSchemaNested.build!(bar: "bar1")
               |> Grax.put(more: [%{bar: "bar1"}, %{bar: "bar2"}])
    end

    test "with a map and without an id or id schema defined for the linked schema" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(:posts, [%{title: "foo"}]) ==
               {:error, "no id schema found"}
    end

    test "with a map for a heterogeneous property" do
      assert_raise ArgumentError, fn ->
        Example.HeterogeneousLinks.build!(EX.Foo)
        |> Grax.put(:one, %{title: "foo"})
      end
    end

    test "with a link property and a wrong Grax.Schema struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put(:next, Example.User.build!(EX.Bar)) ==
               {:error,
                TypeError.exception(
                  value: Example.User.build!(EX.Bar),
                  type: {:resource, Example.SelfLinked}
                )}
    end

    test "with nil value" do
      assert Example.user(EX.User0)
             |> Grax.put(:name, nil) ==
               {:ok, %Example.User{Example.user(EX.User0) | name: nil}}

      assert Example.user(EX.User0)
             |> Grax.put(:email, nil) ==
               {:ok, %Example.User{Example.user(EX.User0) | email: []}}

      assert Example.user(EX.User0)
             |> Grax.put(:posts, nil) ==
               {:ok, %Example.User{Example.user(EX.User0) | posts: []}}

      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put(:next, nil) ==
               {:ok, %Example.SelfLinked{__id__: IRI.new(EX.Foo), next: nil}}
    end
  end

  describe "put!/3" do
    test "when the property exists and the value type matches the schema" do
      assert Example.User.build!(EX.User0)
             |> Grax.put!(:name, "Foo") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo"
               }

      assert Example.user(EX.User0)
             |> Grax.put!(:email, ["foo@example.com"]) ==
               %Example.User{
                 Example.user(EX.User0)
                 | email: ["foo@example.com"]
               }
    end

    test "when the property does not exist" do
      assert_raise KeyError, fn ->
        Example.User.build!(EX.User0)
        |> Grax.put!(:foo, "foo")
      end
    end

    test "when the value type does not match the schema" do
      assert Example.User.build!(EX.User0)
             |> Grax.put!(:age, "secret") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 age: "secret"
               }

      assert Example.Required.build!(EX.Foo)
             |> Grax.put!(:foo, nil) ==
               %Example.Required{
                 __id__: IRI.new(EX.Foo),
                 foo: nil
               }
    end

    test "scalar values on a set property" do
      assert Example.User.build!(EX.User0)
             |> Grax.put!(:email, "foo@example.com") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 email: ["foo@example.com"]
               }
    end

    test "with virtual properties" do
      assert Example.User.build!(EX.User0)
             |> Grax.put!(:password, "secret") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 password: "secret"
               }
    end

    test "with the __id__ field" do
      assert_raise InvalidProperty,
                   "__id__ can't be changed. Use build/2 to construct a new Grax.Schema mapping from another with a new id.",
                   fn ->
                     Example.User.build!(EX.User0)
                     |> Grax.put!(:__id__, "foo")
                   end
    end

    test "with a link property and a proper Grax.Schema struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put!(:next, Example.SelfLinked.build!(EX.Bar)) ==
               %Example.SelfLinked{
                 __id__: IRI.new(EX.Foo),
                 next: Example.SelfLinked.build!(EX.Bar)
               }

      assert Example.User.build!(EX.User0)
             |> Grax.put!(:posts, [Example.post(depth: 0)]) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 posts: [Example.post(depth: 0)]
               }

      assert Example.User.build!(EX.User0)
             |> Grax.put!(:posts, Example.post(depth: 0)) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 posts: [Example.post(depth: 0)]
               }
    end

    test "with a link property and a wrong Grax.Schema struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> Grax.put!(:next, Example.User.build!(EX.Bar)) ==
               %Example.SelfLinked{__id__: IRI.new(EX.Foo), next: Example.User.build!(EX.Bar)}
    end

    test "with a map and an id schema defined for the linked schema" do
      assert %Example.WithIdSchemaNested{
               __id__: ~I<http://example.com/bar/bar1>,
               foo: %Example.WithIdSchema{__id__: nested_id}
             } =
               Example.WithIdSchemaNested.build!(bar: "bar1")
               |> Grax.put!(foo: %{foo: "foo1"})

      assert_valid_uuid(nested_id, "http://example.com/", version: 4, type: :default)
    end
  end

  describe "put/2" do
    test "with a map of valid property values" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(%{
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0)
             }) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  name: "Foo",
                  email: ["foo@example.com"],
                  password: "secret",
                  posts: [Example.post(depth: 0)]
                }}
    end

    test "with a keyword list of valid property values" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(
               name: "Foo",
               email: "foo@example.com",
               password: "secret",
               posts: Example.post(depth: 0)
             ) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  name: "Foo",
                  email: ["foo@example.com"],
                  password: "secret",
                  posts: [Example.post(depth: 0)]
                }}
    end

    test "with invalid property values" do
      assert Example.User.build!(EX.User0)
             |> Grax.put(
               age: "secret",
               foo: "foo",
               posts: Example.User.build!(EX.Bar)
             ) ==
               {:error,
                %ValidationError{
                  context: RDF.iri(EX.User0),
                  errors: [
                    posts:
                      TypeError.exception(
                        value: Example.User.build!(EX.Bar),
                        type: {:resource, Example.Post}
                      ),
                    foo: InvalidProperty.exception(property: :foo),
                    age: TypeError.exception(value: "secret", type: XSD.Integer)
                  ]
                }}
    end
  end

  describe "put!/2" do
    test "with a map of valid property values" do
      assert Example.User.build!(EX.User0)
             |> Grax.put!(%{
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0)
             }) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret",
                 posts: [Example.post(depth: 0)]
               }
    end

    test "with a keyword list of valid property values" do
      assert Example.User.build!(EX.User0)
             |> Grax.put!(
               name: "Foo",
               email: "foo@example.com",
               password: "secret",
               posts: Example.post(depth: 0)
             ) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret",
                 posts: [Example.post(depth: 0)]
               }
    end

    test "with invalid property values" do
      assert Example.User.build!(EX.User0)
             |> Grax.put!(
               name: "Foo",
               age: "secret",
               posts: Example.user(EX.User0)
             ) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo",
                 age: "secret",
                 posts: [Example.user(EX.User0)]
               }
    end
  end

  describe "add_additional_statements/2" do
    test "with RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.add_additional_statements(%{
          EX.p1() => RDF.iri(EX.O1),
          EX.p2() => RDF.iri(EX.O2)
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     EX.p1() => MapSet.new([RDF.iri(EX.O1)]),
                     EX.p2() => MapSet.new([RDF.iri(EX.O2)])
                   }
               }

      assert user
             |> Grax.add_additional_statements(%{
               EX.p1() => ~L"O1",
               EX.p3() => RDF.iri(EX.O3)
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     EX.p1() => MapSet.new([RDF.iri(EX.O1), ~L"O1"]),
                     EX.p2() => MapSet.new([RDF.iri(EX.O2)]),
                     EX.p3() => MapSet.new([RDF.iri(EX.O3)])
                   }
               }
    end

    test "with coercible RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.add_additional_statements(%{
          EX.P1 => EX.O1,
          EX.P2 => EX.O2
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     RDF.iri(EX.P1) => MapSet.new([RDF.iri(EX.O1)]),
                     RDF.iri(EX.P2) => MapSet.new([RDF.iri(EX.O2)])
                   }
               }

      assert user
             |> Grax.add_additional_statements(%{
               EX.P1 => "O1",
               EX.P3 => 1
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     RDF.iri(EX.P1) => MapSet.new([RDF.iri(EX.O1), ~L"O1"]),
                     RDF.iri(EX.P2) => MapSet.new([RDF.iri(EX.O2)]),
                     RDF.iri(EX.P3) => MapSet.new([RDF.XSD.integer(1)])
                   }
               }
    end
  end

  describe "put_additional_statements/2" do
    test "with RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.put_additional_statements(%{
          EX.p1() => RDF.iri(EX.O1),
          EX.p2() => RDF.iri(EX.O2)
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     EX.p1() => MapSet.new([RDF.iri(EX.O1)]),
                     EX.p2() => MapSet.new([RDF.iri(EX.O2)])
                   }
               }

      assert user
             |> Grax.put_additional_statements(%{
               EX.p1() => ~L"O1",
               EX.p3() => RDF.iri(EX.O3)
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     EX.p1() => MapSet.new([~L"O1"]),
                     EX.p2() => MapSet.new([RDF.iri(EX.O2)]),
                     EX.p3() => MapSet.new([RDF.iri(EX.O3)])
                   }
               }
    end

    test "with coercible RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.put_additional_statements(%{
          EX.P1 => EX.O1,
          EX.P2 => EX.O2
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     RDF.iri(EX.P1) => MapSet.new([RDF.iri(EX.O1)]),
                     RDF.iri(EX.P2) => MapSet.new([RDF.iri(EX.O2)])
                   }
               }

      assert user
             |> Grax.put_additional_statements(%{
               EX.P1 => "O1",
               EX.P3 => 1
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     RDF.iri(EX.P1) => MapSet.new([~L"O1"]),
                     RDF.iri(EX.P2) => MapSet.new([RDF.iri(EX.O2)]),
                     RDF.iri(EX.P3) => MapSet.new([RDF.XSD.integer(1)])
                   }
               }
    end

    test "with nil as a value, the property gets deleted from the additional_statements" do
      user =
        Example.user(EX.User0)
        |> Grax.put_additional_statements(%{
          EX.P1 => EX.O1,
          EX.P2 => EX.O2
        })

      assert user
             |> Grax.put_additional_statements(%{
               EX.P1 => nil,
               EX.P2 => 2
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: %{
                     RDF.iri(EX.P2) => MapSet.new([RDF.XSD.integer(2)])
                   }
               }
    end
  end

  test "preload/2" do
    assert Example.user(EX.User0, depth: 0)
           |> Grax.preload(example_graph()) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    graph =
      RDF.graph([
        EX.A |> EX.next(EX.B),
        EX.B |> EX.next(EX.C),
        EX.C |> EX.next(EX.D),
        EX.D |> EX.name("d")
      ])

    assert Example.DepthPreloading.build!(EX.A)
           |> Grax.preload(graph) ==
             Example.DepthPreloading.load(graph, EX.A)

    assert Example.AddDepthPreloading.build!(EX.A)
           |> Grax.preload(graph) ==
             Example.AddDepthPreloading.load(graph, EX.A)
  end

  describe "preload/3" do
    test "without errors" do
      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload(example_graph(), depth: 1) ==
               {:ok, Example.user(EX.User0, depth: 1)}

      assert Example.user(EX.User0, depth: 1)
             |> Grax.preload(example_graph(), depth: 1) ==
               {:ok, Example.user(EX.User0, depth: 1)}

      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload(example_graph(), depth: 2) ==
               {:ok, Example.user(EX.User0, depth: 2)}

      assert Example.user(EX.User0, depth: 1)
             |> Grax.preload(example_graph(), depth: 2) ==
               {:ok, Example.user(EX.User0, depth: 2)}
    end

    test "with validation errors" do
      graph_with_error = example_graph() |> Graph.add({EX.Post0, EX.title(), "Other"})

      assert {:error, %ValidationError{}} =
               Example.user(EX.User0, depth: 0)
               |> Grax.preload(graph_with_error, depth: 1)
    end
  end

  test "preload!/2" do
    assert Example.user(EX.User0, depth: 0)
           |> Grax.preload!(example_graph()) ==
             Example.user(EX.User0, depth: 1)

    graph =
      RDF.graph([
        EX.A |> EX.next(EX.B),
        EX.B |> EX.next(EX.C),
        EX.C |> EX.next(EX.D),
        EX.D |> EX.name("d")
      ])

    assert Example.DepthPreloading.build!(EX.A)
           |> Grax.preload!(graph) ==
             Example.DepthPreloading.load!(graph, EX.A)

    assert Example.AddDepthPreloading.build!(EX.A)
           |> Grax.preload!(graph) ==
             Example.AddDepthPreloading.load!(graph, EX.A)
  end

  describe "preload!/3" do
    test "without errors" do
      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload!(example_graph(), depth: 1) ==
               Example.user(EX.User0, depth: 1)
    end

    test "with validation errors" do
      graph_with_error = example_graph() |> Graph.add({EX.Post0, EX.title(), "Other"})

      post = Example.post(depth: 0)

      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload!(graph_with_error) ==
               Example.user(EX.User0, depth: 1)
               |> Grax.put!(:posts, [Grax.put!(post, :title, [post.title, "Other"])])
    end
  end

  describe "preloaded?/1" do
    test "when one of the link properties is not preloaded" do
      refute Example.user(EX.User0, depth: 0) |> Grax.preloaded?()
      refute Example.post(depth: 0) |> Grax.preloaded?()
    end

    test "when all of the link properties are preloaded" do
      assert Example.user(EX.User0, depth: 1) |> Grax.preloaded?()
      assert Example.post(depth: 1) |> Grax.preloaded?()
    end
  end

  describe "preloaded?/2" do
    test "with preloaded link properties" do
      assert Example.user(EX.User0, depth: 1) |> Grax.preloaded?(:posts)
      assert Example.user(EX.User0, depth: 1) |> Grax.preloaded?(:comments)
      assert Example.post(depth: 1) |> Grax.preloaded?(:author)
      assert Example.post(depth: 1) |> Grax.preloaded?(:comments)
    end

    test "with the link has not preloaded values" do
      refute Example.user(EX.User0, depth: 0) |> Grax.preloaded?(:posts)
      refute Example.post(depth: 0) |> Grax.preloaded?(:author)
      refute Example.post(depth: 0) |> Grax.preloaded?(:comments)
    end

    test "with the link does not have values" do
      assert Example.user(EX.User0, depth: 0) |> Grax.preloaded?(:comments)
    end

    test "with data properties" do
      assert Example.user(EX.User0, depth: 0) |> Grax.preloaded?(:name)
      assert Example.post(depth: 0) |> Grax.preloaded?(:title)
    end

    test "with non-existing properties" do
      assert_raise ArgumentError, fn ->
        Example.post(depth: 0) |> Grax.preloaded?(:not_existing)
      end
    end
  end
end
