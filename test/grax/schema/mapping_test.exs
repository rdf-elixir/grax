defmodule Grax.Schema.MappingTest do
  use Grax.TestCase

  doctest Grax.Schema.Mapping

  defmodule Person do
    use Grax.Schema

    @compile {:no_warn_undefined, Example.NS.EX}
    @compile {:no_warn_undefined, Example.NS.FOAF}

    schema FOAF.Person do
      property name: EX.name(), type: :string
      property mbox: FOAF.mbox(), type: :string
      property homepage: FOAF.homepage(), type: :iri

      field :password
      field :test, default: :some
    end
  end

  defmodule UserWithIris do
    use Grax.Schema

    @compile {:no_warn_undefined, Example.NS.EX}

    schema do
      property posts: EX.post(), type: list_of(:iri)
    end
  end

  test "maps all properties from the other schema struct" do
    user = Example.user(EX.User0, depth: 1)

    assert Person.from(user) ==
             Person.build(EX.User0, name: user.name)
  end

  test "maps fields from the other schema struct" do
    user =
      Example.user(EX.User0, depth: 1)
      |> Grax.put!(:password, "secret")

    assert Person.from(user) ==
             Person.build(EX.User0, name: user.name, password: "secret", test: :some)
  end

  test "maps values from additional_statements" do
    user =
      example_description(:user)
      |> FOAF.mbox("foo@bar.com")
      |> Example.User.load!(EX.User0)

    assert Person.from(user) ==
             Person.build(EX.User0, name: user.name, mbox: "foo@bar.com")
  end

  test "values are selected by property iri, not by name" do
    defmodule UserWithOtherProperties do
      use Grax.Schema

      @compile {:no_warn_undefined, Example.NS.EX}

      schema do
        property foo: EX.name(), type: :string
        property name: EX.otherName(), type: :string
      end
    end

    user = Example.user(EX.User0, depth: 1)

    assert UserWithOtherProperties.from(user) ==
             UserWithOtherProperties.build(EX.User0, foo: user.name)
  end

  test "with non-Grax schema struct input values" do
    assert {:error, "invalid value 42" <> _} = Person.from(42)
    assert {:error, "invalid value" <> _} = Person.from("user")
    assert {:error, "invalid value" <> _} = Person.from(~r/foo/)
  end

  describe "value mapping" do
    test "list with a single value are mapped to the single value, when required" do
      defmodule UserWithSingleEmail do
        use Grax.Schema

        @compile {:no_warn_undefined, Example.NS.EX}

        schema do
          property mail: EX.email(), type: :string
        end
      end

      user =
        Example.user(EX.User0, depth: 1)
        |> Grax.put!(email: "john@doe.com")

      assert UserWithSingleEmail.from(user) ==
               UserWithSingleEmail.build(EX.User0, mail: hd(user.email))
    end

    test "single values are mapped to a list, when required" do
      defmodule UserWithMultipleNames do
        use Grax.Schema

        @compile {:no_warn_undefined, Example.NS.EX}

        schema do
          property names: EX.name(), type: list_of(:string)
        end
      end

      user = Example.user(EX.User0, depth: 1)

      assert UserWithMultipleNames.from(user) ==
               UserWithMultipleNames.build(EX.User0, names: [user.name])
    end
  end

  test "links are mapped to an iri, when required" do
    user = Example.user(EX.User0, depth: 0)

    assert UserWithIris.from(user) ==
             UserWithIris.build(EX.User0, posts: user.posts)

    user_with_links = Example.user(EX.User0, depth: 1)

    assert UserWithIris.from(user_with_links) ==
             UserWithIris.build(EX.User0, posts: user.posts)
  end

  test "iris are mapped to a flat link, when required" do
    user_with_iris = UserWithIris.build!(EX.User0, posts: [RDF.iri(EX.Post0)])

    assert Example.User.from!(user_with_iris) ==
             Example.User.build!(EX.User0, posts: [RDF.iri(EX.Post0)])
  end
end
