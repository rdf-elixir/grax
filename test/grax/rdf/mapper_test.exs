defmodule Grax.RDF.MapperTest do
  use Grax.TestCase

  alias Grax.ValidationError

  import Grax, only: [to_rdf: 1]

  test "successful mapping" do
    assert Example.User.build!(EX.User0,
             name: "John Doe",
             age: 42,
             email: ~w[jd@example.com john@doe.com],
             password: "secret",
             customer_type: :premium_user,
             posts: [
               Example.Post.build!(EX.Post0,
                 title: "Lorem ipsum",
                 content: "Lorem ipsum dolor sit amet, …",
                 author: Example.User.build!(EX.User0),
                 comments: [
                   Example.Comment.build!(EX.Comment1,
                     content: "First",
                     about: Example.Post.build!(EX.Post0),
                     author:
                       Example.User.build!(EX.User1,
                         name: "Erika Mustermann",
                         email: ["erika@mustermann.de"]
                       )
                   ),
                   Example.Comment.build!(EX.Comment2,
                     content: "Second",
                     about: Example.Post.build!(EX.Post0),
                     author:
                       Example.User.build!(EX.User2,
                         name: "Max Mustermann",
                         email: ["max@mustermann.de"]
                       )
                   )
                 ]
               )
             ]
           )
           |> to_rdf() == {:ok, example_graph()}
  end

  test "with invalid struct" do
    assert {:error, %ValidationError{}} =
             Example.User.build!(EX.User0,
               name: "John Doe",
               email: ~w[jd@example.com],
               age: "42"
             )
             |> to_rdf()
  end

  test "mapping of untyped scalar properties" do
    assert Example.Untyped.build!(EX.S, foo: "foo")
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.foo(XSD.string("foo"))
              |> RDF.graph()}

    assert Example.Untyped.build!(EX.S, foo: 42)
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.foo(XSD.integer(42))
              |> RDF.graph()}
  end

  test "mapping of untyped set properties" do
    assert Example.Untyped.build!(EX.S, bar: ["bar"])
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.bar(XSD.string("bar"))
              |> RDF.graph()}

    assert Example.Untyped.build!(EX.S, bar: [42, "bar"])
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.bar(XSD.integer(42), XSD.string("bar"))
              |> RDF.graph()}
  end

  test "type mapping" do
    assert Example.types() |> to_rdf() ==
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
              |> EX.numeric(XSD.integer(42))
              |> EX.date_time(XSD.date_time(~U[2020-01-01 00:00:00Z]))
              |> EX.date(XSD.date(~D[2020-01-01]))
              |> EX.time(XSD.time(~T[00:00:00]))
              |> RDF.graph()}
  end

  test "numeric type" do
    assert Example.Datatypes.build!(EX.S, numeric: 42)
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.numeric(XSD.integer(42))
              |> RDF.graph()}

    assert Example.Datatypes.build!(EX.S, numeric: Decimal.from_float(0.5))
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.numeric(XSD.decimal(0.5))
              |> RDF.graph()}

    assert Example.Datatypes.build!(EX.S, numeric: 3.14)
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.numeric(XSD.double(3.14))
              |> RDF.graph()}
  end

  test "date type" do
    assert Example.Datatypes.build!(EX.S, date: ~D[2020-01-01])
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.date(XSD.date(~D[2020-01-01]))
              |> RDF.graph()}

    assert Example.Datatypes.build!(EX.S, date: {~D[2020-01-01], "Z"})
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.date(XSD.date("2020-01-01Z"))
              |> RDF.graph()}
  end

  test "time type" do
    assert Example.Datatypes.build!(EX.S, time: ~T[00:00:00])
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.time(XSD.time(~T[00:00:00]))
              |> RDF.graph()}

    assert Example.Datatypes.build!(EX.S, time: {~T[00:00:00], true})
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.time(XSD.time("00:00:00Z"))
              |> RDF.graph()}

    assert Example.Datatypes.build!(EX.S, time: {~T[01:00:00], "+01:00"})
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.time(XSD.time("01:00:00+01:00"))
              |> RDF.graph()}
  end

  test "typed set properties" do
    assert Example.Datatypes.build!(EX.S, numerics: [42, 3.14, Decimal.from_float(0.5)])
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.numerics(XSD.integer(42), XSD.double(3.14), XSD.decimal(0.5))
              |> RDF.graph()}
  end

  test "blank node values" do
    assert Example.IdsAsPropertyValues.build!(EX.S,
             foo: ~B"foo",
             foos: [~B"foo", ~B"bar"]
           )
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.foo(~B"foo")
              |> EX.foos(~B"foo", ~B"bar")
              |> RDF.graph()}
  end

  test "IRI values" do
    assert Example.IdsAsPropertyValues.build!(EX.S,
             foo: RDF.iri(EX.Foo),
             foos: [RDF.iri(EX.Bar), RDF.iri(EX.Foo)],
             iri: RDF.iri(EX.Foo),
             iris: [RDF.iri(EX.Bar), RDF.iri(EX.Foo)]
           )
           |> to_rdf() ==
             {:ok,
              EX.S
              |> EX.foo(EX.Foo)
              |> EX.foos(EX.Foo, EX.Bar)
              |> EX.iri(EX.Foo)
              |> EX.iris(EX.Foo, EX.Bar)
              |> RDF.graph()}
  end

  test "inverse properties" do
    assert Example.InverseProperties.build!(EX.S,
             name: "subject",
             foo: [Example.user(EX.User0, depth: 0)]
           )
           |> to_rdf() ==
             {:ok,
              [
                EX.S |> EX.name("subject"),
                EX.User0 |> EX.foo(EX.S),
                example_description(:user)
                |> Description.delete_predicates(EX.post())
              ]
              |> RDF.graph()}
  end

  test "rdf:type for schema class is defined" do
    assert Example.ClassDeclaration.build!(EX.S, name: "foo")
           |> to_rdf() ==
             {:ok,
              EX.S
              |> RDF.type(EX.Class)
              |> EX.name("foo")
              |> RDF.graph()}
  end

  describe "custom mapping" do
    test "untyped data properties" do
      assert Example.CustomMapping.build!(EX.S,
               foo: {:foo, "foo"},
               foos: [{:foo, "foo1"}, {:foo, "foo2"}]
             )
             |> to_rdf() ==
               {:ok,
                EX.S
                |> EX.foo(~L"foo")
                |> EX.foos(~L"foo1", ~L"foo2")
                |> RDF.graph()}
    end

    test "typed data properties" do
      assert Example.CustomMapping.build!(EX.S, bar: "test")
             |> to_rdf() ==
               {:ok,
                EX.S
                |> EX.bar(EX.test())
                |> RDF.graph()}
    end

    test "creation of additional triples" do
      assert Example.CustomMapping.build!(EX.S, bars: ["test1", "test2"])
             |> to_rdf() ==
               {:ok,
                EX.S
                |> EX.bars(EX.test1())
                |> EX.other(EX.test2())
                |> RDF.graph()}
    end

    test "when the custom to_rdf mapping returns an error tuple" do
      assert Example.CustomMapping.build!(EX.S, bars: ["test1"])
             |> to_rdf() ==
               {:error, "not enough bars"}
    end

    test "when the mapping function is on a separate module" do
      assert Example.CustomMappingInSeparateModule.build!(EX.S, foo: "FOO")
             |> to_rdf() ==
               {:ok,
                EX.S
                |> EX.foo("foo")
                |> RDF.graph()}
    end
  end
end
