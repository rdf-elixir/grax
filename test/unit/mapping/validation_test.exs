defmodule RDF.Mapping.ValidationTest do
  use RDF.Mapping.TestCase

  alias RDF.Mapping.{ValidationError, InvalidSubjectIRIError}
  alias RDF.Mapping.Schema.TypeError

  describe "subject IRI validation" do
    test "when missing" do
      assert Example.User.validate(%Example.User{}, []) ==
               {:error, validation_error(__iri__: InvalidSubjectIRIError.exception(iri: nil))}
    end
  end

  test "default values of optional values are always valid" do
    [
      %Example.Types{__iri__: IRI.to_string(EX.S)},
      %Example.User{__iri__: IRI.to_string(EX.S)}
    ]
    |> Enum.each(fn %mapping_mod{} = empty_mapping ->
      assert mapping_mod.validate(empty_mapping, []) == {:ok, empty_mapping}
    end)
  end

  describe "datatype validation" do
    test "literals with proper datatype and cardinality" do
      assert Example.types() |> Example.Types.validate([]) == {:ok, Example.types()}

      [
        name: nil,
        name: "foo",
        email: [],
        email: ["foo@example.com"],
        email: ["foo@example.com", "bar@example.com"]
      ]
      |> assert_ok_validation(%Example.User{__iri__: IRI.to_string(EX.S)})

      [
        numeric: Decimal.from_float(0.5)
      ]
      |> assert_ok_validation(%Example.Types{__iri__: IRI.to_string(EX.S)})

      [
        foo: nil,
        foo: "foo",
        foo: 42,
        bar: [],
        bar: ["bar"],
        bar: ["bar", 42, Decimal.from_float(0.5), 3.14]
      ]
      |> assert_ok_validation(%Example.Untyped{__iri__: IRI.to_string(EX.S)})
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
        negative_integer: 42
      ]

      assert_validation_error(
        bad_values,
        Example.types(),
        TypeError,
        &[
          value: &1,
          type: Example.Types.__property_spec__(&2).type
        ]
      )

      assert {:error, %ValidationError{errors: errors}} =
               bad_values
               |> Enum.reduce(Example.types(), fn {property, value}, mapping ->
                 Map.put(mapping, property, value)
               end)
               |> Example.Types.validate([])

      assert errors |> Keyword.keys() |> MapSet.new() ==
               bad_values |> Keyword.keys() |> MapSet.new()

      [
        email: [42]
      ]
      |> assert_validation_error(
        %Example.User{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: hd(&1),
          type: Example.User.__property_spec__(&2).type |> elem(1)
        ]
      )
    end

    test "when scalar value is a list" do
      [
        name: [],
        name: ["foo"]
      ]
      |> assert_validation_error(
        %Example.User{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.User.__property_spec__(&2).type
        ]
      )

      [
        foo: [],
        foo: ["foo"]
      ]
      |> assert_validation_error(
        %Example.Untyped{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Untyped.__property_spec__(&2).type
        ]
      )
    end

    test "when set value is a scalar" do
      [
        email: "foo@example.com",
        email: nil
      ]
      |> assert_validation_error(
        %Example.User{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.User.__property_spec__(&2).type
        ]
      )

      [
        bar: "bar",
        bar: nil
      ]
      |> assert_validation_error(
        %Example.Untyped{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Untyped.__property_spec__(&2).type
        ]
      )
    end

    test "multiple errors per property" do
      assert Example.User.validate(%Example.User{__iri__: IRI.to_string(EX.S), name: [42]}, []) ==
               {:error,
                validation_error(
                  name: TypeError.exception(type: XSD.String, value: [42]),
                  name: TypeError.exception(type: XSD.String, value: 42)
                )}

      assert Example.User.validate(%Example.User{__iri__: IRI.to_string(EX.S), email: 42}, []) ==
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
      |> assert_ok_validation(%Example.User{__iri__: IRI.to_string(EX.S)})

      [
        author: Example.user(EX.User0)
      ]
      |> assert_ok_validation(%Example.Post{__iri__: IRI.to_string(EX.S)})
    end

    test "when scalar value is a list" do
      [
        author: [],
        author: [Example.user(EX.User0)]
      ]
      |> assert_validation_error(
        %Example.Post{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Post.__link_spec__(&2).type
        ]
      )
    end

    test "when set value is a scalar" do
      [
        posts: nil,
        posts: Example.post()
      ]
      |> assert_validation_error(
        %Example.User{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.User.__link_spec__(&2).type
        ]
      )
    end

    test "with wrong struct type" do
      [
        author: Example.post(),
        author: %{}
      ]
      |> assert_validation_error(
        %Example.Post{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: &1,
          type: Example.Post.__link_spec__(&2).type
        ]
      )

      [
        posts: [Example.user(EX.User0)],
        posts: [%{}]
      ]
      |> assert_validation_error(
        %Example.User{__iri__: IRI.to_string(EX.S)},
        TypeError,
        &[
          value: hd(&1),
          type: Example.User.__link_spec__(&2).type |> elem(1)
        ]
      )
    end

    test "when the nested mapping is invalid" do
      [
        author: %Example.User{},
        author: %Example.User{__iri__: IRI.to_string(EX.S), name: 42}
      ]
      |> assert_validation_error(%Example.Post{__iri__: IRI.to_string(EX.S)}, ValidationError)

      [
        posts: [%Example.Post{}],
        posts: [%Example.Post{__iri__: IRI.to_string(EX.S), title: 42}],
      ]
      |> assert_validation_error(%Example.User{__iri__: IRI.to_string(EX.S)}, ValidationError)
    end
  end

  defp assert_ok_validation(properties, %mapping_mod{} = mapping) do
    Enum.each(properties, fn {property, value} ->
      mapping = Map.put(mapping, property, value)

      assert mapping_mod.validate(mapping, []) == {:ok, mapping}
      assert mapping_mod.validate!(mapping, []) == mapping
      assert mapping_mod.valid?(mapping, []) == true
    end)
  end

  defp assert_validation_error(failing_properties, %mapping_mod{} = mapping, error) do
    Enum.each(failing_properties, fn {property, value} ->
      mapping = Map.put(mapping, property, value)

      assert {:error, %^error{}} = mapping_mod.validate(mapping, [])

      assert_raise ValidationError, fn ->
        mapping_mod.validate!(mapping, [])
      end

      assert mapping_mod.valid?(mapping, []) == false
    end)
  end

  defp assert_validation_error(failing_properties, %mapping_mod{} = mapping, error, error_args) do
    Enum.each(failing_properties, fn {property, value} ->
      mapping = Map.put(mapping, property, value)

      assert mapping_mod.validate(mapping, []) ==
               {:error,
                validation_error([
                  {property, error.exception(error_args.(value, property))}
                ])}

      assert_raise ValidationError, fn ->
        mapping_mod.validate!(mapping, [])
      end

      assert mapping_mod.valid?(mapping, []) == false
    end)
  end

  defp validation_error(errors) do
    Enum.reduce(errors, ValidationError.exception(), fn
      {property, error}, validation ->
        ValidationError.add_error(validation, property, error)
    end)
  end
end
