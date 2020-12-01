defmodule RDF.Mapping.SchemaTest do
  use RDF.Test.Case

  test "has_one and has_many without a type raise a proper error" do
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
