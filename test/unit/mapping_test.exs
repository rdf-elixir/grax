defmodule RDF.MappingTest do
  use RDF.Mapping.TestCase

  doctest RDF.Mapping

  alias RDF.Mapping.ValidationError
  alias RDF.Mapping.Schema.{TypeError, InvalidProperty, RequiredPropertyMissing}

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

  describe "build/2" do
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

    test "with another mapping of the same type" do
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
                  errors: [
                    age: TypeError.exception(value: "secret", type: XSD.Integer)
                  ]
                }}
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

    test "with another mapping of the same type" do
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
             |> RDF.Mapping.put(:name, "Foo") ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  name: "Foo"
                }}

      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:email, ["foo@example.com"]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  email: ["foo@example.com"]
                }}
    end

    test "when the property does not exist" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:foo, "foo") ==
               {:error, InvalidProperty.exception(property: :foo)}
    end

    test "when the value type does not match the schema" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:age, "secret") ==
               {:error, TypeError.exception(value: "secret", type: XSD.Integer)}

      assert Example.Required.build!(EX.Foo)
             |> RDF.Mapping.put(:foo, nil) ==
               {:error, RequiredPropertyMissing.exception(property: :foo)}
    end

    test "scalar values on a set property" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:email, "foo@example.com") ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  email: ["foo@example.com"]
                }}
    end

    test "previous values are overwritten" do
      assert Example.user(EX.User0)
             |> RDF.Mapping.put(:name, "Foo") ==
               {:ok, %Example.User{Example.user(EX.User0) | name: "Foo"}}

      assert Example.user(EX.User0)
             |> RDF.Mapping.put(:email, ["foo@example.com"]) ==
               {:ok, %Example.User{Example.user(EX.User0) | email: ["foo@example.com"]}}
    end

    test "with virtual properties" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:password, "secret") ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  password: "secret"
                }}
    end

    test "with the __id__ field" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:__id__, "foo") ==
               {:error,
                InvalidProperty.exception(
                  property: :__id__,
                  message:
                    "__id__ can't be changed. Use build/2 to construct a mapping from another with new id."
                )}
    end

    test "with a link property and a proper mapping struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> RDF.Mapping.put(:next, Example.SelfLinked.build!(EX.Bar)) ==
               {:ok,
                %Example.SelfLinked{
                  __id__: IRI.new(EX.Foo),
                  next: Example.SelfLinked.build!(EX.Bar)
                }}

      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:posts, [Example.post(depth: 0)]) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  posts: [Example.post(depth: 0)]
                }}

      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(:posts, Example.post(depth: 0)) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  posts: [Example.post(depth: 0)]
                }}
    end

    test "with a link property and a wrong mapping struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> RDF.Mapping.put(:next, Example.User.build!(EX.Bar)) ==
               {:error,
                TypeError.exception(
                  value: Example.User.build!(EX.Bar),
                  type: {:resource, Example.SelfLinked}
                )}
    end

    test "with nil value" do
      assert Example.user(EX.User0)
             |> RDF.Mapping.put(:name, nil) ==
               {:ok, %Example.User{Example.user(EX.User0) | name: nil}}

      assert Example.user(EX.User0)
             |> RDF.Mapping.put(:email, nil) ==
               {:ok, %Example.User{Example.user(EX.User0) | email: []}}

      assert Example.user(EX.User0)
             |> RDF.Mapping.put(:posts, nil) ==
               {:ok, %Example.User{Example.user(EX.User0) | posts: []}}

      assert Example.SelfLinked.build!(EX.Foo)
             |> RDF.Mapping.put(:next, nil) ==
               {:ok, %Example.SelfLinked{__id__: IRI.new(EX.Foo), next: nil}}
    end
  end

  describe "put!/3" do
    test "when the property exists and the value type matches the schema" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put!(:name, "Foo") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 name: "Foo"
               }

      assert Example.user(EX.User0)
             |> RDF.Mapping.put!(:email, ["foo@example.com"]) ==
               %Example.User{
                 Example.user(EX.User0)
                 | email: ["foo@example.com"]
               }
    end

    test "when the property does not exist" do
      assert_raise KeyError, fn ->
        Example.User.build!(EX.User0)
        |> RDF.Mapping.put!(:foo, "foo")
      end
    end

    test "when the value type does not match the schema" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put!(:age, "secret") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 age: "secret"
               }

      assert Example.Required.build!(EX.Foo)
             |> RDF.Mapping.put!(:foo, nil) ==
               %Example.Required{
                 __id__: IRI.new(EX.Foo),
                 foo: nil
               }
    end

    test "scalar values on a set property" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put!(:email, "foo@example.com") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 email: ["foo@example.com"]
               }
    end

    test "with virtual properties" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put!(:password, "secret") ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 password: "secret"
               }
    end

    test "with the __id__ field" do
      assert_raise InvalidProperty,
                   "__id__ can't be changed. Use build/2 to construct a mapping from another with new id.",
                   fn ->
                     Example.User.build!(EX.User0)
                     |> RDF.Mapping.put!(:__id__, "foo")
                   end
    end

    test "with a link property and a proper mapping struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> RDF.Mapping.put!(:next, Example.SelfLinked.build!(EX.Bar)) ==
               %Example.SelfLinked{
                 __id__: IRI.new(EX.Foo),
                 next: Example.SelfLinked.build!(EX.Bar)
               }

      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put!(:posts, [Example.post(depth: 0)]) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 posts: [Example.post(depth: 0)]
               }

      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put!(:posts, Example.post(depth: 0)) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 posts: [Example.post(depth: 0)]
               }
    end

    test "with a link property and a wrong mapping struct" do
      assert Example.SelfLinked.build!(EX.Foo)
             |> RDF.Mapping.put!(:next, Example.User.build!(EX.Bar)) ==
               %Example.SelfLinked{__id__: IRI.new(EX.Foo), next: Example.User.build!(EX.Bar)}
    end
  end

  describe "put/2" do
    test "with a map of valid property values" do
      assert Example.User.build!(EX.User0)
             |> RDF.Mapping.put(%{
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
             |> RDF.Mapping.put(
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
             |> RDF.Mapping.put(
               age: "secret",
               foo: "foo",
               posts: Example.User.build!(EX.Bar)
             ) ==
               {:error,
                %ValidationError{
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
             |> RDF.Mapping.put!(%{
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
             |> RDF.Mapping.put!(
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
             |> RDF.Mapping.put!(
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

  test "__has_property__?/2" do
    assert Example.User.__has_property__?(:name) == true
    assert Example.User.__has_property__?(:posts) == true
    assert Example.User.__has_property__?(:password) == true
    assert Example.User.__has_property__?(:foo) == false
    assert Example.User.__has_property__?(:__id__) == false
  end
end
