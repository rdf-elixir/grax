defmodule Grax.ValidationTest do
  use Grax.TestCase

  alias Grax.{ValidationError, InvalidIdError}
  alias Grax.Schema.{TypeError, RequiredPropertyMissing}

  import Grax,
    only: [
      validate: 1,
      validate!: 1,
      valid?: 1
    ]

  describe "subject id validation" do
    test "with a blank node" do
      assert validate(%Example.User{__id__: ~B"foo"}) ==
               {:ok, %Example.User{__id__: ~B"foo"}}
    end

    test "with an invalid value" do
      assert validate(%Example.User{__id__: "http://example.com"}) ==
               {:error,
                validation_error(__id__: InvalidIdError.exception(id: "http://example.com"))}
    end

    test "when missing" do
      assert validate(%Example.User{}) ==
               {:error, validation_error(__id__: InvalidIdError.exception(id: nil))}
    end
  end

  test "default values of optional values are always valid" do
    [
      %Example.Types{__id__: IRI.new(EX.S)},
      %Example.User{__id__: IRI.new(EX.S)}
    ]
    |> Enum.each(fn empty_mapping ->
      assert validate(empty_mapping) == {:ok, empty_mapping}
    end)
  end

  describe "datatype validation" do
    test "literals with proper datatype and cardinality" do
      assert Example.types() |> validate() == {:ok, Example.types()}

      [
        name: nil,
        name: "foo",
        email: [],
        email: ["foo@example.com"],
        email: ["foo@example.com", "bar@example.com"]
      ]
      |> assert_ok_validation(%Example.User{__id__: IRI.new(EX.S)})

      [
        numeric: Decimal.from_float(0.5),
        date: {~D[2020-01-01], "Z"},
        time: {~T[00:00:00], true},
        time: {~T[00:00:00], "+01:00"}
      ]
      |> assert_ok_validation(%Example.Types{__id__: IRI.new(EX.S)})

      [
        foo: nil,
        foo: "foo",
        foo: 42,
        bar: [],
        bar: ["bar"],
        bar: ["bar", 42, Decimal.from_float(0.5), 3.14]
      ]
      |> assert_ok_validation(%Example.Untyped{__id__: IRI.new(EX.S)})
    end

    test "literal datatype mismatches" do
      bad_values = [
        string: 42,
        string: Decimal.from_float(0.5),
        any_uri: "http://example.com/",
        boolean: 0,
        boolean: "true",
        numeric: "invalid",
        numeric: "42",
        integer: "invalid",
        integer: "42",
        integer: Decimal.from_float(0.5),
        float: "invalid",
        float: "3.14",
        float: 42,
        float: Decimal.from_float(0.5),
        double: "invalid",
        double: "3.14",
        double: 42,
        double: Decimal.from_float(0.5),
        long: "42",
        long: 9_223_372_036_854_775_808,
        long: Decimal.from_float(0.5),
        int: "42",
        int: 2_147_483_648,
        long: Decimal.from_float(0.5),
        short: "42",
        short: 32768,
        byte: "42",
        byte: 128,
        non_negative_integer: "42",
        non_negative_integer: -42,
        positive_integer: "42",
        positive_integer: -42,
        unsigned_long: "42",
        unsigned_long: -42,
        unsigned_int: "42",
        unsigned_int: -42,
        unsigned_short: "42",
        unsigned_short: -42,
        unsigned_byte: "42",
        unsigned_byte: -42,
        unsigned_byte: Decimal.from_float(0.5),
        non_positive_integer: "-42",
        non_positive_integer: 42,
        negative_integer: "-42",
        negative_integer: 42,
        date_time: "invalid",
        date_time: "2020-01-01T00:00:00Z",
        date: "2020-01-01",
        time: "00:00:00"
      ]

      assert_validation_error(
        bad_values,
        Example.types(),
        TypeError,
        &[
          value: &1,
          type: Example.Types.__property__(&2).type
        ]
      )

      assert {:error, %ValidationError{errors: errors}} =
               bad_values
               |> Enum.reduce(Example.types(), fn {property, value}, mapping ->
                 Map.put(mapping, property, value)
               end)
               |> validate()

      assert errors |> Keyword.keys() |> MapSet.new() ==
               bad_values |> Keyword.keys() |> MapSet.new()

      [
        email: [42]
      ]
      |> assert_validation_error(
        %Example.User{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: hd(&1),
          type: Example.User.__property__(&2).type |> elem(1)
        ]
      )
    end

    test "when scalar value is a list" do
      [
        name: [],
        name: ["foo"]
      ]
      |> assert_validation_error(
        %Example.User{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.User.__property__(&2).type
        ]
      )

      [
        foo: [],
        foo: ["foo"]
      ]
      |> assert_validation_error(
        %Example.Untyped{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Untyped.__property__(&2).type
        ]
      )
    end

    test "when set value is a scalar" do
      [
        email: "foo@example.com",
        email: nil
      ]
      |> assert_validation_error(
        %Example.User{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.User.__property__(&2).type
        ]
      )

      [
        bar: "bar",
        bar: nil
      ]
      |> assert_validation_error(
        %Example.Untyped{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Untyped.__property__(&2).type
        ]
      )
    end

    test "missing required properties" do
      assert validate(%Example.Required{__id__: IRI.new(EX.S)}) ==
               {:error,
                validation_error(
                  bar: RequiredPropertyMissing.exception(property: :bar),
                  baz: RequiredPropertyMissing.exception(property: :baz),
                  foo: RequiredPropertyMissing.exception(property: :foo)
                )}
    end

    test "multiple errors per property" do
      assert validate(%Example.User{__id__: IRI.new(EX.S), name: [42]}) ==
               {:error,
                validation_error(
                  name: TypeError.exception(type: XSD.String, value: [42]),
                  name: TypeError.exception(type: XSD.String, value: 42)
                )}

      assert validate(%Example.User{__id__: IRI.new(EX.S), email: 42}) ==
               {:error,
                validation_error(
                  email: TypeError.exception(type: {:set, XSD.String}, value: 42),
                  email: TypeError.exception(type: XSD.String, value: 42)
                )}
    end
  end

  describe "link validation" do
    test "proper type and cardinality" do
      [
        posts: [Example.post()]
      ]
      |> assert_ok_validation(%Example.User{__id__: IRI.new(EX.S)})

      [
        author: Example.user(EX.User0)
      ]
      |> assert_ok_validation(%Example.Post{__id__: IRI.new(EX.S)})
    end

    test "when scalar value is a list" do
      [
        author: [],
        author: [Example.user(EX.User0)]
      ]
      |> assert_validation_error(
        %Example.Post{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Post.__property__(&2).type
        ]
      )
    end

    test "when set value is a scalar" do
      [
        posts: nil,
        posts: Example.post()
      ]
      |> assert_validation_error(
        %Example.User{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.User.__property__(&2).type
        ]
      )
    end

    test "with wrong struct type" do
      [
        author: Example.post(),
        author: %{}
      ]
      |> assert_validation_error(
        %Example.Post{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Post.__property__(&2).type
        ]
      )

      [
        posts: [Example.user(EX.User0)],
        posts: [%{}]
      ]
      |> assert_validation_error(
        %Example.User{__id__: IRI.new(EX.S)},
        TypeError,
        &[
          value: hd(&1),
          type: Example.User.__property__(&2).type |> elem(1)
        ]
      )
    end

    test "when the nested mapping is invalid" do
      [
        author: %Example.User{},
        author: %Example.User{__id__: IRI.new(EX.S), name: 42}
      ]
      |> assert_validation_error(%Example.Post{__id__: IRI.new(EX.S)}, ValidationError)

      [
        posts: [%Example.Post{}],
        posts: [%Example.Post{__id__: IRI.new(EX.S), title: 42}]
      ]
      |> assert_validation_error(%Example.User{__id__: IRI.new(EX.S)}, ValidationError)
    end
  end

  test "blank node values" do
    assert %Example.IdsAsPropertyValues{
             __id__: RDF.iri(EX.S),
             foo: ~B"foo",
             foos: [~B"bar", ~B"foo"]
           }
           |> valid?()

    [
      name: ~B"foo"
    ]
    |> assert_validation_error(
      %Example.User{__id__: IRI.new(EX.S)},
      TypeError,
      &[
        value: &1,
        type: Example.User.__property__(&2).type
      ]
    )

    [
      email: [~B"foo"]
    ]
    |> assert_validation_error(
      %Example.User{__id__: IRI.new(EX.S)},
      TypeError,
      &[
        value: hd(&1),
        type: Example.User.__property__(&2).type |> elem(1)
      ]
    )
  end

  test "IRI values" do
    assert %Example.IdsAsPropertyValues{
             __id__: RDF.iri(EX.S),
             foo: RDF.iri(EX.Foo),
             foos: [RDF.iri(EX.Bar), RDF.iri(EX.Foo)],
             iri: RDF.iri(EX.Foo),
             iris: [RDF.iri(EX.Bar), RDF.iri(EX.Foo)]
           }
           |> valid?()

    [
      iri: "foo"
    ]
    |> assert_validation_error(
      %Example.IdsAsPropertyValues{__id__: IRI.new(EX.S)},
      TypeError,
      &[
        value: &1,
        type: Example.IdsAsPropertyValues.__property__(&2).type
      ]
    )

    [
      name: EX.foo()
    ]
    |> assert_validation_error(
      %Example.User{__id__: IRI.new(EX.S)},
      TypeError,
      &[
        value: &1,
        type: Example.User.__property__(&2).type
      ]
    )

    [
      email: [EX.foo()]
    ]
    |> assert_validation_error(
      %Example.User{__id__: IRI.new(EX.S)},
      TypeError,
      &[
        value: hd(&1),
        type: Example.User.__property__(&2).type |> elem(1)
      ]
    )
  end

  defp assert_ok_validation(properties, mapping) do
    Enum.each(properties, fn {property, value} ->
      mapping = Map.put(mapping, property, value)

      assert validate(mapping) == {:ok, mapping}
      assert validate!(mapping) == mapping
      assert valid?(mapping) == true
    end)
  end

  defp assert_validation_error(failing_properties, mapping, error) do
    Enum.each(failing_properties, fn {property, value} ->
      mapping = Map.put(mapping, property, value)

      assert {:error, %^error{}} = validate(mapping)

      assert_raise ValidationError, fn -> validate!(mapping) end

      assert valid?(mapping) == false
    end)
  end

  defp assert_validation_error(failing_properties, mapping, error, error_args) do
    Enum.each(failing_properties, fn {property, value} ->
      mapping = Map.put(mapping, property, value)

      assert validate(mapping) ==
               {:error,
                validation_error([
                  {property, error.exception(error_args.(value, property))}
                ])}

      assert_raise ValidationError, fn ->
        validate!(mapping)
      end

      assert valid?(mapping) == false
    end)
  end

  defp validation_error(errors) do
    Enum.reduce(errors, ValidationError.exception(), fn
      {property, error}, validation ->
        ValidationError.add_error(validation, property, error)
    end)
  end
end
