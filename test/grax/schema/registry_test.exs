defmodule Grax.Schema.RegistryTest do
  use Grax.TestCase

  alias Grax.Schema.Registry

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

  test "all_schemas/0" do
    all_schemas = Registry.all_schemas()

    assert is_list(all_schemas)
    refute Enum.empty?(all_schemas)
    assert Enum.all?(all_schemas, &Grax.Schema.schema?/1)
    assert all_schemas == Enum.uniq(all_schemas)
  end

  describe "register/1" do
    test "with a Grax schema" do
      defmodule DynamicallyCreatedSchema do
        use Grax.Schema

        schema EX.DynamicallyCreatedSchema < Example.ParentSchema do
        end
      end

      refute Registry.schema(RDF.iri(EX.DynamicallyCreatedSchema))
      assert :ok = Registry.register(DynamicallyCreatedSchema)
      assert Registry.schema(RDF.iri(EX.DynamicallyCreatedSchema)) == DynamicallyCreatedSchema

      assert Registry.reset()
    end
  end

  test "completeness" do
    for schema <- Grax.Schema.Loader.load_all(), not is_nil(schema.__class__) do
      assert Registry.schema(RDF.iri(schema.__class__)) == schema or
               schema in Registry.schema(RDF.iri(schema.__class__))
    end
  end
end
