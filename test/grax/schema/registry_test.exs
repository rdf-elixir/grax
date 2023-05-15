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
    assert Enum.sort(Registry.all_schemas()) ==
             [
               Example.AddDepthPreloading,
               Example.AnotherParentSchema,
               Example.AnyType,
               Example.Cardinalities,
               Example.ChildOfMany,
               Example.ChildSchema,
               Example.ChildSchemaWithClass,
               Example.Circle,
               Example.ClassDeclaration,
               Example.Comment,
               Example.CustomMapping,
               Example.CustomMappingInSeparateModule,
               Example.CustomMappingOnCustomFields,
               Example.Datatypes,
               Example.DefaultValues,
               Example.DepthPreloading,
               Example.IdsAsPropertyValues,
               Example.IgnoreAdditionalStatements,
               Example.InverseProperties,
               Example.LanguageStrings,
               Example.Links,
               Example.MultipleSchemasA,
               Example.MultipleSchemasB,
               Example.NonPolymorphicLink,
               Example.ParentSchema,
               Example.PolymorphicLink,
               Example.Post,
               Example.Required,
               Example.SelfLinked,
               Example.SingularInverseProperties,
               Example.Untyped,
               Example.User,
               Example.UserWithCallbacks,
               Example.VarMappingA,
               Example.VarMappingB,
               Example.VarMappingC,
               Example.VarMappingD,
               Example.WithBlankNodeIdSchema,
               Example.WithCustomSelectedIdSchemaA,
               Example.WithCustomSelectedIdSchemaB,
               Example.WithIdSchema,
               Example.WithIdSchemaNested,
               Example.ZeroDepthLinkPreloading,
               Example.ZeroDepthPreloading
             ]
             |> Enum.uniq()
             |> Enum.sort()
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
