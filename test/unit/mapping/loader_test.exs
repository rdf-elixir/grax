defmodule RDF.Mapping.LoaderTest do
  use RDF.Test.Case

  alias RDF.Mapping.DescriptionNotFoundError

  #  defmodule TestMappingArgs do
  #    use RDF.Mapping
  #
  #    schema do
  #      property :arg_test, EX.arg_test()
  #    end
  #
  #    def handle_from_rdf(:arg_test, _, %Description{} = desc, %Graph{} = graph, opts) do
  #      assert desc == Keyword.get(opts, :description)
  #      assert graph == Keyword.get(opts, :graph)
  #    end
  #  end

  test "successful mapping from a graph" do
    assert Example.User.load(example_graph(), EX.User) ==
             {:ok, Example.user(EX.User)}
  end

  test "successful mapping from a description" do
    assert example_description(:user)
           |> Description.delete_predicates(EX.post())
           |> Example.User.load(EX.User) ==
             {:ok, %Example.User{Example.user(EX.User) | posts: []}}
  end

  test "with non-RDF.Data" do
    assert_raise ArgumentError, "invalid input data: %{}", fn ->
      Example.User.load(%{}, EX.User)
    end
  end

  test "when no description for the given IRI exists in the graph" do
    assert Example.User.load(example_graph(), EX.not_existing()) ==
             {:error, DescriptionNotFoundError.exception(resource: EX.not_existing())}
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
             #      |> EX.date(XSD.date(42))
             #      |> EX.time(XSD.time(42))
             #      |> EX.date_time(XSD.date_time(42))
             |> Example.Types.load(EX.S) ==
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
             |> Example.Types.load(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  numeric: 42
                }}

      assert EX.S
             |> EX.numeric(XSD.decimal(0.5))
             |> Example.Types.load(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  numeric: Decimal.from_float(0.5)
                }}

      assert EX.S
             |> EX.numeric(XSD.float(3.14))
             |> Example.Types.load(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  numeric: 3.14
                }}
    end

    test "untyped scalar properties" do
      assert EX.S |> EX.foo("foo") |> Example.Untyped.load(EX.S) ==
               {:ok,
                %Example.Untyped{
                  __iri__: IRI.to_string(EX.S),
                  foo: "foo"
                }}

      assert EX.S |> EX.foo(42) |> Example.Untyped.load(EX.S) ==
               {:ok,
                %Example.Untyped{
                  __iri__: IRI.to_string(EX.S),
                  foo: 42
                }}
    end

    test "untyped set properties" do
      assert EX.S |> EX.bar("bar") |> Example.Untyped.load(EX.S) ==
               {:ok,
                %Example.Untyped{
                  __iri__: IRI.to_string(EX.S),
                  bar: ["bar"]
                }}

      assert EX.S |> EX.bar("bar", 42) |> Example.Untyped.load(EX.S) ==
               {:ok,
                %Example.Untyped{
                  __iri__: IRI.to_string(EX.S),
                  bar: [42, "bar"]
                }}
    end

    test "typed set properties" do
      assert EX.S
             |> EX.integers(XSD.integer(1))
             |> Example.Types.load(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  integers: [1]
                }}

      assert EX.S
             |> EX.integers(XSD.integer(1), XSD.byte(2), XSD.negativeInteger(-3))
             |> Example.Types.load(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  integers: [2, 1, -3]
                }}

      assert EX.S
             |> EX.numerics(XSD.integer(42), XSD.decimal(0.5), XSD.float(3.14))
             |> Example.Types.load(EX.S) ==
               {:ok,
                %Example.Types{
                  __iri__: IRI.to_string(EX.S),
                  numerics: [Decimal.from_float(0.5), 3.14, 42]
                }}
    end

    test "type derivations are taken into account" do
      assert {:ok, %Example.Types{int: 42}} =
               EX.S |> EX.int(XSD.byte(42)) |> Example.Types.load(EX.S)

      assert {:ok, %Example.Types{double: 3.14}} =
               EX.S |> EX.double(XSD.float(3.14)) |> Example.Types.load(EX.S)
    end

    test "when a type does not match the definition in the schema" do
      assert {:error,
              %RDF.Mapping.Schema.TypeError{
                type: XSD.Integer,
                value: ~L"invalid"
              }} = EX.S |> EX.integer("invalid") |> Example.Types.load(EX.S)

      integer = XSD.integer(-42)

      assert {:error,
              %RDF.Mapping.Schema.TypeError{
                type: XSD.UnsignedByte,
                value: ^integer
              }} = EX.S |> EX.unsigned_byte(integer) |> Example.Types.load(EX.S)

      # TODO: Do we really wanna be that strict?
      integer = XSD.integer(42)

      assert {:error,
              %RDF.Mapping.Schema.TypeError{
                type: XSD.UnsignedByte,
                value: ^integer
              }} = EX.S |> EX.unsigned_byte(integer) |> Example.Types.load(EX.S)
    end

    test "with invalid literals" do
      invalid = XSD.integer("invalid")

      assert {:error, %RDF.Mapping.InvalidValueError{value: ^invalid}} =
               EX.S |> EX.integer(invalid) |> Example.Types.load(EX.S)
    end
  end

  test "when multiple values exist for a scalar property" do
    assert {:error, %RDF.Mapping.Schema.TypeError{type: XSD.String}} =
             example_graph()
             |> Graph.add({EX.User, EX.name(), "Jane"})
             |> Example.User.load(EX.User)
  end

  describe "nested mappings" do
    test "when no description of the associated resource exists" do
      assert example_description(:user)
             |> EX.posts(EX.Post)
             |> Example.User.load(EX.User) ==
               {:error, DescriptionNotFoundError.exception(resource: RDF.iri(EX.Post))}
    end

    test "when the nested description doesn't match the nested schema" do
      assert {:error, %RDF.Mapping.Schema.TypeError{type: XSD.String}} =
               example_graph()
               |> Graph.add({EX.Post, EX.title(), "Other"})
               |> Example.User.load(EX.User)

      assert {:error, %RDF.Mapping.Schema.TypeError{type: XSD.String}} =
               example_graph()
               |> Graph.put({EX.Post, EX.title(), 42})
               |> Example.User.load(EX.User)
    end
  end
end
