if String.to_integer(System.otp_release()) >= 25 do
  defmodule Grax.JsonPropertyTest do
    use Grax.TestCase

    alias Grax.ValidationError
    alias Grax.Schema.{TypeError, CardinalityError}

    @valid_values [
      "foo",
      42,
      true,
      false,
      [1, 2, 3],
      %{"a" => 1},
      %{
        "array" => [1, "two", true],
        "object" => %{"nested" => "value"},
        "null" => nil
      }
    ]

    @invalid_values [
      :foo,
      [:bar],
      %{%{a: 1} => 2}
    ]

    test "Grax.build!/2" do
      assert Example.JsonType.build!(EX.Foo) ==
               %Example.JsonType{
                 __id__: IRI.new(EX.Foo),
                 foo: nil,
                 bar: []
               }

      Enum.each(@valid_values, fn valid_value ->
        assert Example.JsonType.build!(EX.Foo, foo: valid_value) ==
                 %Example.JsonType{
                   __id__: IRI.new(EX.Foo),
                   foo: valid_value,
                   bar: []
                 }
      end)
    end

    describe "Grax.put/2" do
      test "with valid values" do
        Enum.each(@valid_values, fn valid_value ->
          assert Example.JsonType.build!(EX.Foo)
                 |> Grax.put(:foo, valid_value) ==
                   {:ok,
                    %Example.JsonType{
                      __id__: IRI.new(EX.Foo),
                      foo: valid_value
                    }}

          assert Example.JsonType.build!(EX.Foo)
                 |> Grax.put(:bar, [valid_value]) ==
                   {:ok,
                    %Example.JsonType{
                      __id__: IRI.new(EX.Foo),
                      bar: [valid_value]
                    }}
        end)
      end

      test "with null value" do
        assert Example.JsonType.build!(EX.Foo)
               |> Grax.put(:foo, :null) ==
                 {:ok,
                  %Example.JsonType{
                    __id__: IRI.new(EX.Foo),
                    foo: :null
                  }}
      end

      test "with nil value" do
        assert Example.JsonType.build!(EX.Foo)
               |> Grax.put(:foo, nil) ==
                 {:ok,
                  %Example.JsonType{
                    __id__: IRI.new(EX.Foo),
                    foo: nil
                  }}

        assert Example.JsonType.build!(EX.Foo)
               |> Grax.put(:bar, nil) ==
                 {:ok,
                  %Example.JsonType{
                    __id__: IRI.new(EX.Foo),
                    bar: []
                  }}
      end

      test "with invalid values" do
        Enum.each(@invalid_values, fn invalid_value ->
          assert {:error, %TypeError{}} =
                   Example.JsonType.build!(EX.Foo)
                   |> Grax.put(:foo, invalid_value)

          assert {:error, %TypeError{}} =
                   Example.JsonType.build!(EX.Foo)
                   |> Grax.put(:bar, [invalid_value])
        end)
      end
    end

    describe "load/2" do
      test "with valid values" do
        Enum.each(@valid_values, fn value ->
          assert Graph.new()
                 |> Graph.add({EX.S, EX.foo(), RDF.JSON.new(value, as_value: true)})
                 |> Example.JsonType.load(EX.S) ==
                   Example.JsonType.build(EX.S, foo: value)

          assert Graph.new()
                 |> Graph.add({EX.S, EX.bar(), RDF.JSON.new(value, as_value: true)})
                 |> Example.JsonType.load(EX.S) ==
                   Example.JsonType.build(EX.S, bar: [value])

          assert Graph.new()
                 |> Graph.add({EX.S, EX.foo(), RDF.JSON.new(value, as_value: true)})
                 |> Graph.add({EX.S, EX.bar(), RDF.JSON.new(value, as_value: true)})
                 |> Example.JsonTypeRequired.load(EX.S) ==
                   Example.JsonTypeRequired.build(EX.S, foo: value, bar: [value])
        end)
      end

      test "with null value" do
        assert Graph.new()
               |> Graph.add({EX.S, EX.foo(), RDF.JSON.new(nil)})
               |> Example.JsonType.load(EX.S) ==
                 Example.JsonType.build(EX.S, foo: :null)

        assert Graph.new()
               |> Graph.add({EX.S, EX.bar(), RDF.JSON.new(nil)})
               |> Example.JsonType.load(EX.S) ==
                 Example.JsonType.build(EX.S, bar: [nil])

        assert Graph.new()
               |> Graph.add({EX.S, EX.foo(), RDF.JSON.new(nil)})
               |> Graph.add({EX.S, EX.bar(), RDF.JSON.new(nil)})
               |> Example.JsonTypeRequired.load(EX.S) ==
                 Example.JsonTypeRequired.build(EX.S, foo: :null, bar: [nil])
      end

      test "without value" do
        assert Graph.new() |> Example.JsonType.load(EX.S) ==
                 Example.JsonType.build(EX.S, foo: nil, bar: [])

        assert {
                 :error,
                 %ValidationError{
                   errors: [foo: %CardinalityError{cardinality: 1, value: nil}]
                 }
               } =
                 Graph.new()
                 |> Graph.add({EX.S, EX.bar(), RDF.JSON.new(nil)})
                 |> Example.JsonTypeRequired.load(EX.S)

        assert {
                 :error,
                 %ValidationError{
                   errors: [bar: %CardinalityError{cardinality: {:min, 1}, value: []}]
                 }
               } =
                 Graph.new()
                 |> Graph.add({EX.S, EX.foo(), RDF.JSON.new(nil)})
                 |> Example.JsonTypeRequired.load(EX.S)
      end
    end

    describe "Grax.to_rdf/2" do
      test "with valid value" do
        Enum.each(@valid_values, fn value ->
          assert Example.JsonType.build!(EX.S, foo: value)
                 |> Grax.to_rdf() ==
                   {:ok,
                    EX.S
                    |> EX.foo(RDF.JSON.new(value, as_value: true))
                    |> RDF.graph()}

          assert Example.JsonType.build!(EX.S, bar: [value])
                 |> Grax.to_rdf() ==
                   {:ok,
                    EX.S
                    |> EX.bar(RDF.JSON.new(value, as_value: true))
                    |> RDF.graph()}
        end)
      end

      test "with null value" do
        assert Example.JsonType.build!(EX.S, foo: :null)
               |> Grax.to_rdf() ==
                 {:ok,
                  EX.S
                  |> EX.foo(RDF.JSON.new(nil))
                  |> RDF.graph()}
      end

      test "without value" do
        assert Example.JsonType.build!(EX.S, foo: nil, bar: [])
               |> Grax.to_rdf() ==
                 {:ok, RDF.graph()}
      end
    end
  end
end
