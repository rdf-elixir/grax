defmodule Grax.RDF.LoaderTest do
  use Grax.TestCase

  alias Grax.{ValidationError, InvalidValueError}
  alias Grax.Schema.TypeError

  test "successful mapping from a graph" do
    assert Example.User.load(example_graph(), EX.User0) ==
             {:ok, Example.user(EX.User0, depth: 1)}
  end

  test "successful mapping from a description" do
    assert example_description(:user)
           |> Description.delete_predicates(EX.post())
           |> Example.User.load(EX.User0) ==
             {:ok, %Example.User{Example.user(EX.User0, depth: 1) | posts: []}}
  end

  test "with a description of blank node" do
    assert example_description(:user)
           |> Description.delete_predicates(EX.post())
           |> Description.change_subject(~B"user0")
           |> Example.User.load(~B"user0") ==
             {:ok, %{Example.user(EX.User0, depth: 1) | __id__: ~B"user0", posts: []}}
  end

  test "with non-RDF.Data" do
    assert_raise ArgumentError, "invalid input data: %{}", fn ->
      Example.User.load(%{}, EX.User0)
    end
  end

  test "when no description for the given IRI exists in the graph" do
    assert Example.User.load(example_graph(), EX.not_existing()) ==
             Example.User.build(EX.not_existing(), posts: [], comments: [])
  end

  test "blank node values" do
    assert EX.S
           |> EX.foo(~B"foo")
           |> EX.foos(~B"foo", ~B"bar")
           |> Example.IdsAsPropertyValues.load(EX.S, []) ==
             Example.IdsAsPropertyValues.build(EX.S,
               foo: ~B"foo",
               foos: [~B"bar", ~B"foo"]
             )
  end

  test "IRI values" do
    assert EX.S
           |> EX.foo(EX.Foo)
           |> EX.foos(EX.Foo, EX.Bar)
           |> EX.iri(EX.Foo)
           |> EX.iris(EX.Foo, EX.Bar)
           |> Example.IdsAsPropertyValues.load(EX.S, []) ==
             Example.IdsAsPropertyValues.build(EX.S,
               foo: RDF.iri(EX.Foo),
               foos: [RDF.iri(EX.Bar), RDF.iri(EX.Foo)],
               iri: RDF.iri(EX.Foo),
               iris: [RDF.iri(EX.Bar), RDF.iri(EX.Foo)]
             )
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
             |> EX.numeric(XSD.integer(42))
             |> EX.date_time(XSD.date_time("2020-01-01T00:00:00Z"))
             |> EX.date(XSD.date(~D[2020-01-01]))
             |> EX.time(XSD.time(~T[00:00:00]))
             |> Example.Datatypes.load(EX.S) ==
               {:ok, Example.types()}
    end

    test "numeric type" do
      assert EX.S
             |> EX.numeric(XSD.integer(42))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, numeric: 42)

      assert EX.S
             |> EX.numeric(XSD.decimal(0.5))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, numeric: Decimal.from_float(0.5))

      assert EX.S
             |> EX.numeric(XSD.float(3.14))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, numeric: 3.14)
    end

    test "date type" do
      assert EX.S
             |> EX.date(XSD.date(~D[2020-01-01]))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, date: ~D[2020-01-01])

      assert EX.S
             |> EX.date(XSD.date("2020-01-01Z"))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, date: {~D[2020-01-01], "Z"})
    end

    test "time type" do
      assert EX.S
             |> EX.time(XSD.time(~T[00:00:00]))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, time: ~T[00:00:00])

      assert EX.S
             |> EX.time(XSD.time("00:00:00Z"))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, time: {~T[00:00:00], true})
    end

    test "untyped scalar properties" do
      assert EX.S |> EX.foo("foo") |> Example.Untyped.load(EX.S) ==
               Example.Untyped.build(EX.S, foo: "foo")

      assert EX.S |> EX.foo(42) |> Example.Untyped.load(EX.S) ==
               Example.Untyped.build(EX.S, foo: 42)
    end

    test "untyped set properties" do
      assert EX.S |> EX.bar("bar") |> Example.Untyped.load(EX.S) ==
               Example.Untyped.build(EX.S, bar: ["bar"])

      assert EX.S |> EX.bar("bar", 42) |> Example.Untyped.load(EX.S) ==
               Example.Untyped.build(EX.S, bar: [42, "bar"])
    end

    test "typed set properties" do
      assert EX.S
             |> EX.integers(XSD.integer(1))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, integers: [1])

      assert EX.S
             |> EX.integers(XSD.integer(1), XSD.byte(2), XSD.negativeInteger(-3))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, integers: [2, 1, -3])

      assert EX.S
             |> EX.numerics(XSD.integer(42), XSD.decimal(0.5), XSD.float(3.14))
             |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, numerics: [Decimal.from_float(0.5), 3.14, 42])
    end

    test "type derivations are taken into account" do
      assert EX.S |> EX.int(XSD.byte(42)) |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, int: 42)

      assert EX.S |> EX.double(XSD.float(3.14)) |> Example.Datatypes.load(EX.S) ==
               Example.Datatypes.build(EX.S, double: 3.14)
    end

    test "load/2 when a type does not match the definition in the schema" do
      assert {:error,
              %ValidationError{
                errors: [
                  integer: %TypeError{
                    type: XSD.Integer,
                    value: "invalid"
                  }
                ]
              }} = EX.S |> EX.integer("invalid") |> Example.Datatypes.load(EX.S)
    end

    test "load/2 when a literal is given instead of an URI for a link" do
      assert {:error, %Grax.RDF.Preloader.Error{}} =
               example_description(:post)
               |> Description.put({EX.author(), "Jane Doe"})
               |> Example.Post.load(EX.Post0)
    end

    test "load!/2 when a type does not match the definition in the schema" do
      assert result =
               %Example.Datatypes{integer: "invalid"} =
               EX.S |> EX.integer("invalid") |> Example.Datatypes.load!(EX.S)

      refute Grax.valid?(result)

      assert result =
               %Example.Datatypes{unsigned_byte: -42} =
               EX.S |> EX.unsigned_byte(-42) |> Example.Datatypes.load!(EX.S)

      refute Grax.valid?(result)
    end

    test "load/2 with invalid literals" do
      invalid = XSD.integer("invalid")

      assert {:error, %InvalidValueError{value: ^invalid}} =
               EX.S |> EX.integer(invalid) |> Example.Datatypes.load(EX.S)
    end

    test "load!/2 with invalid literals" do
      assert_raise InvalidValueError, fn ->
        EX.S |> EX.integer(XSD.integer("invalid")) |> Example.Datatypes.load!(EX.S)
      end
    end
  end

  test "load/2 when multiple values exist for a scalar property" do
    assert {:error, %ValidationError{}} =
             example_graph()
             |> Graph.add({EX.User0, EX.name(), "Jane"})
             |> Example.User.load(EX.User0)
  end

  test "load!/2 when multiple values exist for a scalar property" do
    assert %Example.User{} =
             user =
             example_graph()
             |> Graph.add({EX.User0, EX.name(), "Jane"})
             |> Example.User.load!(EX.User0)

    refute Grax.valid?(user)
    assert user.name == ["Jane", Example.user(EX.User0).name]
  end

  describe "preloading of nested mappings" do
    test "when no description of the associated resource exists" do
      assert example_description(:user)
             |> Example.User.load(EX.User0) ==
               {:ok,
                Example.user(EX.User0, depth: 1)
                |> Map.put(:posts, [Example.Post.build!(EX.Post0)])}
    end

    test "load/2 when the nested description doesn't match the nested schema" do
      assert {:error, %ValidationError{}} =
               example_graph()
               |> Graph.add({EX.Post0, EX.title(), "Other"})
               |> Example.User.load(EX.User0)
    end

    test "load!/2 when the nested description doesn't match the nested schema" do
      assert %Example.User{} =
               user =
               example_graph()
               |> Graph.add({EX.Post0, EX.title(), "Other"})
               |> Example.User.load!(EX.User0)

      refute Grax.valid?(user)
      assert hd(user.posts).title == [Example.post().title, "Other"]

      assert %Example.User{} =
               user =
               example_graph()
               |> Graph.put({EX.Post0, EX.title(), 42})
               |> Example.User.load!(EX.User0)

      refute Grax.valid?(user)
      assert hd(user.posts).title == 42
    end
  end

  describe "inverse properties" do
    test "normal case" do
      description = EX.S |> EX.name("subject")

      assert Example.InverseProperties.load(description, EX.S) ==
               Example.InverseProperties.build(EX.S, name: "subject", foo: [])

      graph =
        Graph.new([
          description,
          EX.User0 |> EX.foo(EX.S),
          example_graph()
        ])

      assert Example.InverseProperties.load(graph, EX.S) ==
               Example.InverseProperties.build(EX.S,
                 name: "subject",
                 foo: [
                   Example.user(EX.User0, depth: 0)
                   |> Grax.put_additional_statements(%{EX.foo() => EX.S})
                 ]
               )

      assert Example.InverseProperties.load(graph, EX.S, depth: 2) ==
               Example.InverseProperties.build(EX.S,
                 name: "subject",
                 foo: [
                   Example.user(EX.User0, depth: 1)
                   |> Grax.put_additional_statements(%{EX.foo() => EX.S})
                 ]
               )
    end

    test "when a resource exists only as an object" do
      graph =
        Graph.new([
          EX.User0 |> EX.foo(EX.S),
          example_graph()
        ])

      assert Example.InverseProperties.load(graph, EX.S) ==
               Example.InverseProperties.build(EX.S,
                 foo: [
                   Example.user(EX.User0, depth: 0)
                   |> Grax.put_additional_statements(%{EX.foo() => EX.S})
                 ]
               )
    end
  end

  describe "custom mapping on data properties" do
    test "untyped data properties" do
      assert EX.S
             |> EX.foo(~L"foo")
             |> EX.foos(~L"foo1", ~L"foo2")
             |> Example.CustomMapping.load(EX.S) ==
               Example.CustomMapping.build(EX.S,
                 foo: {:foo, "foo"},
                 foos: [{:foo, "foo1"}, {:foo, "foo2"}]
               )
    end

    test "typed data properties" do
      assert EX.S
             |> EX.bar(EX.test())
             |> EX.bars(EX.test1(), EX.test2())
             |> Example.CustomMapping.load(EX.S) ==
               Example.CustomMapping.build(EX.S,
                 bar: "test",
                 bars: ["test1", "test2"]
               )
    end

    test "when the custom from_rdf mapping returns an error tuple" do
      assert EX.S
             |> EX.foo(~L"foo1", ~L"foo2")
             |> Example.CustomMapping.load(EX.S) ==
               {:error, "multiple :foo values found"}
    end

    test "when the mapping function is on a separate module" do
      assert EX.S
             |> EX.foo(~L"foo")
             |> Example.CustomMappingInSeparateModule.load(EX.S) ==
               Example.CustomMappingInSeparateModule.build(EX.S, foo: "FOO", bar: "bar")
    end
  end

  describe "custom mapping on custom fields" do
    test "when the mapping function returns an ok tuple" do
      uuid = "9fb44168-90f9-4d9c-a057-5dacb3adc104"
      uuid_urn = "urn:uuid:#{uuid}"

      assert uuid_urn
             |> EX.foo("foo")
             |> Example.CustomMappingOnCustomFields.load!(uuid_urn) ==
               Example.CustomMappingOnCustomFields.build!(uuid_urn,
                 uuid: uuid,
                 __additional_statements__: %{EX.foo() => "foo"}
               )
    end

    test "when the mapping function returns an error tuple" do
      assert EX.S
             |> EX.foo("foo")
             |> Example.CustomMappingOnCustomFields.load(EX.S) ==
               {:error, "invalid id"}
    end
  end

  describe "additional statements" do
    test "when additional_statements is enabled (default)" do
      assert example_graph()
             |> Graph.add(EX.User0 |> EX.p(EX.O))
             |> Example.User.load(EX.User0) ==
               {:ok,
                Example.user(EX.User0, depth: 1)
                |> Grax.put_additional_statements(%{EX.p() => EX.O})}

      assert example_graph()
             |> Graph.add(EX.User0 |> EX.p([EX.O1, EX.O2]))
             |> Example.User.load(EX.User0) ==
               {:ok,
                Example.user(EX.User0, depth: 1)
                |> Grax.put_additional_statements(%{EX.p() => [EX.O1, EX.O2]})}
    end

    test "when additional_statements is disabled" do
      assert EX.S
             |> EX.foo("foo")
             |> EX.bar("bar")
             |> RDF.graph()
             |> Example.IgnoreAdditionalStatements.load(EX.S) ==
               Example.IgnoreAdditionalStatements.build(EX.S, foo: "foo")
    end
  end
end
