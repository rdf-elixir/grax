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
      assert {:error, "name canonical_email for UUID generation not present"} =
               IdSpecs.HashUuids.expected_id_schema(Example.User)
               |> Example.User.build(%{name: "Foo"})
    end

    test "when schema is associated with an id schema it is used implicitly" do
      assert {:ok, %Example.WithIdSchema{__id__: id, foo: "Foo"}} =
               Example.WithIdSchema.build(%{foo: "Foo"})

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)

      assert {:ok, %Example.WithIdSchema{__id__: id, foo: "Foo"}} =
               Example.WithIdSchema.build(foo: "Foo")

      assert_valid_uuid(id, "http://example.com/", version: 4, type: :default)
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
end
