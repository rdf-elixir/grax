defmodule Grax.Schema.RegistryTest do
  use Grax.TestCase, async: false

  alias Grax.Schema.Registry

  @registry_of_all_schemas %{
    ~I<http://example.com/Class> => %{
      Example.ClassDeclaration => nil,
      Example.IgnoreAdditionalStatements => nil
    },
    ~I<http://example.com/Comment> => %{
      Example.Comment => nil
    },
    ~I<http://example.com/Post> => %{
      Example.Post => nil
    },
    ~I<http://example.com/User> => %{
      Example.User => nil,
      Example.UserWithCallbacks => nil
    },
    ~I<http://example.com/SubClass> => %{
      Example.ChildOfMany => nil
    },
    ~I<http://example.com/Child2> => %{
      Example.ChildSchemaWithClass => [Example.ChildOfMany]
    },
    ~I<http://example.com/Parent> => %{
      Example.ParentSchema => [
        Example.ChildOfMany,
        Example.ChildSchemaWithClass,
        Example.ChildSchema
      ]
    },
    ~I<http://example.com/Parent2> => %{
      Example.AnotherParentSchema => [Example.ChildOfMany]
    }
  }

  describe "schema/1" do
    test "when no schema for the given IRI exists" do
      assert Registry.schema(RDF.iri(EX.Unknown)) == nil
    end

    test "when a unique schema exists for a given iri" do
      assert Registry.schema(RDF.iri(EX.Post)) == Example.Post
    end

    test "when multiple schemas exists for a given iri" do
      assert EX.User |> RDF.iri() |> Registry.schema() |> Enum.sort() ==
               Enum.sort([Example.UserWithCallbacks, Example.User])
    end
  end

  describe "inherited_schemas/1" do
    test "when the given schema is not registered" do
      assert Registry.inherited_schemas(Foo) == nil
      assert Registry.inherited_schemas(Regex) == nil
      assert Registry.inherited_schemas(Example.Untyped) == nil
    end

    test "when the given schema has no inherited schemas" do
      assert Registry.inherited_schemas(RDF.iri(EX.User)) == nil
      assert Registry.inherited_schemas(RDF.iri(EX.Post)) == nil
    end

    test "when a unique schema with inherited schemas exists for a given iri" do
      assert Enum.sort(Registry.inherited_schemas(Example.ParentSchema)) ==
               Enum.sort([Example.ChildOfMany, Example.ChildSchemaWithClass, Example.ChildSchema])
    end

    test "when multiple schemas exists for a given iri" do
    end
  end

  describe "register/1" do
    test "with a Grax schema" do
      defmodule DynamicallyCreatedSchema do
        use Grax.Schema

        schema EX.DynamicallyCreatedSchema < Example.ParentSchema do
        end
      end

      refute Registry.schema(RDF.iri(EX.DynamicallyCreatedSchema))
      refute Registry.inherited_schemas(DynamicallyCreatedSchema)
      assert :ok = Registry.register(DynamicallyCreatedSchema)
      assert Registry.schema(RDF.iri(EX.DynamicallyCreatedSchema)) == DynamicallyCreatedSchema
      assert DynamicallyCreatedSchema in Registry.inherited_schemas(Example.ParentSchema)

      assert Registry.reset()
    end
  end

  test "completeness" do
    for {iri, record} <- @registry_of_all_schemas, {schema, inherited} <- record do
      case map_size(record) do
        0 ->
          raise "unexpected schema count"

        1 ->
          assert Registry.schema(RDF.iri(iri)) == schema

        _ ->
          assert Enum.sort(Registry.schema(RDF.iri(iri))) ==
                   Enum.sort(Map.keys(record))
      end

      assert Registry.inherited_schemas(schema) == inherited
    end
  end
end
