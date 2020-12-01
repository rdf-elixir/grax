defmodule RDF.Mapping.SchemaTest do
  use RDF.Test.Case

  alias RDF.Mapping.Association

  describe "default values" do
    test "on properties and associations" do
      assert %Example.DefaultValues{} ==
               %Example.DefaultValues{
                 foo: "foo",
                 bar: "bar",
                 baz: 42,
                 user: %Association.NotLoaded{
                   __owner__: Example.DefaultValues,
                   __field__: :user,
                   __cardinality__: :one
                 },
                 posts: %Association.NotLoaded{
                   __owner__: Example.DefaultValues,
                   __field__: :posts,
                   __cardinality__: :many
                 }
               }
    end

    test "associations don't support custom defaults" do
      assert_raise ArgumentError, "the :default option is not supported on associations", fn ->
        defmodule AssociationWithDefault do
          use RDF.Mapping

          schema do
            has_one :a, EX.a(), type: A, default: :foo
          end
        end
      end
    end

    test "property sets don't support custom defaults" do
      assert_raise ArgumentError, "the :default option is not supported on sets", fn ->
        defmodule AssociationWithDefault do
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

  test "associations without a type raise a proper error" do
    assert_raise ArgumentError, "type missing for property a", fn ->
      defmodule HasOneNil do
        use RDF.Mapping

        schema do
          has_one :a, EX.a(), type: nil
        end
      end
    end

    assert_raise ArgumentError, "type missing for property a", fn ->
      defmodule HasManyNil do
        use RDF.Mapping

        schema do
          has_many :a, EX.a(), type: nil
        end
      end
    end
  end
end
