defmodule RDF.Mapping.FromRDFTest do
  use RDF.Test.Case

  test "successful mapping from a graph" do
    assert Example.User.from_rdf(example_graph(), EX.User) ==
             {:ok,
              %Example.User{
                __iri__: IRI.to_string(EX.User),
                name: "John Doe",
                age: 42
              }}
  end

  test "successful mapping from a description" do
    assert Example.User.from_rdf(example_description(), EX.User) ==
             {:ok,
              %Example.User{
                __iri__: IRI.to_string(EX.User),
                name: "John Doe",
                age: 42
              }}
  end

  test "with non-RDF.Data" do
    assert_raise ArgumentError, "invalid input data: %{}", fn ->
      Example.User.from_rdf(%{}, EX.User)
    end
  end

  test "when no description for the given IRI exists in the graph" do
    assert Example.User.from_rdf(example_graph(), EX.not_existing()) ==
             {:error, "No description of #{inspect(EX.not_existing())} found."}
  end

  describe "type mapping" do
    test "typed properties" do
      assert EX.S
             |> EX.string(XSD.string("string"))
             |> EX.any_uri(XSD.any_uri(EX.foo()))
             |> EX.boolean(XSD.true())
             |> EX.integer(XSD.integer(42))
             |> EX.decimal(XSD.decimal(0.5))
             |> EX.double(XSD.double(3.14))
             |> EX.float(XSD.float(3.14))
             |> EX.long(XSD.long(42))
             |> EX.int(XSD.int(42))
             |> EX.short(XSD.short(42))
             |> EX.byte(XSD.byte(42))
             |> EX.non_negative_integer(XSD.nonNegativeInteger(42))
             |> EX.positive_integer(XSD.positiveInteger(42))
             |> EX.unsigned_long(XSD.unsignedLong(42))
             |> EX.unsigned_int(XSD.unsignedInt(42))
             |> EX.unsigned_short(XSD.unsignedShort(42))
             |> EX.unsigned_byte(XSD.unsignedByte(42))
             |> EX.non_positive_integer(XSD.nonPositiveInteger(-42))
             |> EX.negative_integer(XSD.negativeInteger(-42))
             |> Example.Types.from_rdf(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  string: "string",
                  any_uri: IRI.parse(EX.foo()),
                  boolean: true,
                  integer: 42,
                  decimal: Decimal.from_float(0.5),
                  double: 3.14,
                  float: 3.14,
                  long: 42,
                  int: 42,
                  short: 42,
                  byte: 42,
                  non_negative_integer: 42,
                  positive_integer: 42,
                  unsigned_long: 42,
                  unsigned_int: 42,
                  unsigned_short: 42,
                  unsigned_byte: 42,
                  non_positive_integer: -42,
                  negative_integer: -42
                }}
    end

    test "numeric type" do
      assert EX.S
             |> EX.numeric(XSD.integer(42))
             |> Example.Types.from_rdf(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  numeric: 42
                }}

      assert EX.S
             |> EX.numeric(XSD.decimal(0.5))
             |> Example.Types.from_rdf(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  numeric: Decimal.from_float(0.5)
                }}

      assert EX.S
             |> EX.numeric(XSD.float(3.14))
             |> Example.Types.from_rdf(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  numeric: 3.14
                }}
    end

    test "untyped properties" do
      assert EX.S |> EX.foo("foo") |> Example.Untyped.from_rdf(EX.S) ==
               {:ok,
                %Example.Untyped{
                  __iri__: IRI.to_string(EX.S),
                  foo: "foo"
                }}
    end

    test "type derivations are taken into account" do
      assert {:ok, %Example.Types{int: 42}} =
               EX.S |> EX.int(XSD.byte(42)) |> Example.Types.from_rdf(EX.S)

      assert {:ok, %Example.Types{double: 3.14}} =
               EX.S |> EX.double(XSD.float(3.14)) |> Example.Types.from_rdf(EX.S)
    end

    test "when a type does not match the definition in the schema" do
      assert {:error,
              %RDF.Mapping.Schema.TypeError{
                type: XSD.Integer,
                value: ~L"invalid"
              }} = EX.S |> EX.integer("invalid") |> Example.Types.from_rdf(EX.S)

      integer = XSD.integer(-42)

      assert {:error,
              %RDF.Mapping.Schema.TypeError{
                type: XSD.UnsignedByte,
                value: ^integer
              }} = EX.S |> EX.unsigned_byte(integer) |> Example.Types.from_rdf(EX.S)

      # TODO: Do we really wanna be that strict?
      integer = XSD.integer(42)

      assert {:error,
              %RDF.Mapping.Schema.TypeError{
                type: XSD.UnsignedByte,
                value: ^integer
              }} = EX.S |> EX.unsigned_byte(integer) |> Example.Types.from_rdf(EX.S)
    end

    test "with invalid literals" do
      invalid = XSD.integer("invalid")

      assert {:error, %RDF.Mapping.InvalidValueError{value: ^invalid}} =
               EX.S |> EX.integer(invalid) |> Example.Types.from_rdf(EX.S)
    end
  end
end
