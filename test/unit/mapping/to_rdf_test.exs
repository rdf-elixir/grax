defmodule RDF.Mapping.ToRDFTest do
  use RDF.Test.Case

  test "successful mapping" do
    assert %Example.User{
             __iri__: IRI.to_string(EX.User),
             name: "John Doe",
             age: 42
           }
           |> Example.User.to_rdf() == {:ok, example_graph()}
  end

  test "mapping of untyped properties" do
    assert %Example.Untyped{
             __iri__: IRI.to_string(EX.S),
             foo: "foo"
           }
           |> Example.Untyped.to_rdf() ==
             {:ok,
              EX.S
              |> EX.foo(XSD.string("foo"))
              |> RDF.graph()}

    assert %Example.Untyped{
             __iri__: IRI.to_string(EX.S),
             foo: 42
           }
           |> Example.Untyped.to_rdf() ==
             {:ok,
              EX.S
              |> EX.foo(XSD.integer(42))
              |> RDF.graph()}
  end

  test "type mapping" do
    assert %Example.Types{
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
           }
           |> Example.Types.to_rdf() ==
             {:ok,
              EX.S
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
              |> RDF.graph()}
  end
end
