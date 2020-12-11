defmodule RDF.Mapping.SchemaTest do
  use RDF.Mapping.TestCase

  alias RDF.Mapping.Link

  describe "default values" do
    test "on properties and links" do
      assert %Example.DefaultValues{} ==
               %Example.DefaultValues{
                 foo: "foo",
                 bar: "bar",
                 baz: 42,
                 user: %Link.NotLoaded{
                   __owner__: Example.DefaultValues,
                   __field__: :user
                 },
                 posts: %Link.NotLoaded{
                   __owner__: Example.DefaultValues,
                   __field__: :posts
                 }
               }
    end

    test "links don't support custom defaults" do
      assert_raise ArgumentError, "the :default option is not supported on links", fn ->
        defmodule LinkWithDefault do
          use RDF.Mapping

          schema do
            link :a, EX.a(), type: A, default: :foo
          end
        end
      end
    end

    test "property sets don't support custom defaults" do
      assert_raise ArgumentError, "the :default option is not supported on sets", fn ->
        defmodule LinkWithDefault do
          use RDF.Mapping

          schema do
            property :a, EX.a(), type: [], default: :foo
          end
        end
      end
    end
  end

  test "type of default values must match the type" do
    assert_raise ArgumentError,
                 ~S(default value "foo" doesn't match type Elixir.RDF.XSD.Integer),
                 fn ->
                   defmodule DefaultValueTypeMismatch do
                     use RDF.Mapping

                     schema do
                       property :a, EX.a(), type: :integer, default: "foo"
                     end
                   end
                 end
  end

  test "links without a type raise a proper error" do
    assert_raise ArgumentError, "type missing for property a", fn ->
      defmodule NilLink do
        use RDF.Mapping

        schema do
          link :a, EX.a(), type: nil
        end
      end
    end
  end

  test "property_mapping/1" do
    assert RDF.Mapping.Schema.property_mapping(
             foo: EX.foo(),
             bar: EX.Bar,
             baz: {:inverse, EX.Baz}
           ) ==
             %{
               foo: RDF.iri(EX.foo()),
               bar: RDF.iri(EX.Bar),
               baz: {:inverse, RDF.iri(EX.Baz)}
             }
  end

  test "__class__/0" do
    assert Example.ClassDeclaration.__class__() == IRI.to_string(EX.Class)
    assert Example.Types.__class__() == nil
  end
end
