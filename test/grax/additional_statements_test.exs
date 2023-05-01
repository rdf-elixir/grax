defmodule Grax.AdditionalStatementsTest do
  use Grax.TestCase

  alias Grax.Schema.AdditionalStatements

  describe "Grax.build/2" do
    test "with __additional_statements__ map" do
      assert Example.User.build(EX.User0, %{
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0),
               __additional_statements__: %{
                 EX.P1 => EX.O1,
                 EX.P2 => "foo"
               }
             }) ==
               {:ok,
                %Example.User{
                  __id__: IRI.new(EX.User0),
                  __additional_statements__:
                    AdditionalStatements.new(%{
                      RDF.type() => [RDF.iri(EX.User)],
                      EX.P1 => [RDF.iri(EX.O1)],
                      EX.P2 => [~L"foo"]
                    }),
                  name: "Foo",
                  email: ["foo@example.com"],
                  password: "secret",
                  posts: [Example.post(depth: 0)]
                }}
    end
  end

  describe "Grax.build!/2" do
    test "with __additional_statements__ map" do
      assert Example.User.build!(EX.User0, %{
               name: "Foo",
               email: ["foo@example.com"],
               password: "secret",
               posts: Example.post(depth: 0),
               __additional_statements__: %{
                 EX.P1 => EX.O1,
                 EX.P2 => "foo"
               }
             }) ==
               %Example.User{
                 __id__: IRI.new(EX.User0),
                 __additional_statements__:
                   AdditionalStatements.new(%{
                     RDF.type() => RDF.iri(EX.User),
                     EX.P1 => RDF.iri(EX.O1),
                     EX.P2 => ~L"foo"
                   }),
                 name: "Foo",
                 email: ["foo@example.com"],
                 password: "secret",
                 posts: [Example.post(depth: 0)]
               }
    end

    test "additional rdf:type statement for schema class is defined" do
      assert Example.ClassDeclaration.build!(EX.S, name: "foo").__additional_statements__ ==
               AdditionalStatements.new(%{RDF.type() => EX.Class})
    end
  end

  test "Grax.additional_statements/1" do
    example =
      Example.User.build!(EX.User0, %{
        name: "Foo",
        email: ["foo@example.com"],
        password: "secret",
        posts: Example.post(depth: 0),
        __additional_statements__: %{
          EX.P1 => EX.O1,
          EX.P2 => "foo"
        }
      })

    assert Grax.additional_statements(example) ==
             RDF.description(EX.User0,
               init: %{
                 RDF.type() => EX.User,
                 EX.P1 => EX.O1,
                 EX.P2 => "foo"
               }
             )
  end

  describe "Grax.add_additional_statements/2" do
    test "with RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.add_additional_statements(%{
          EX.p1() => RDF.iri(EX.O1),
          EX.p2() => RDF.iri(EX.O2)
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => RDF.iri(EX.User),
                       EX.p1() => RDF.iri(EX.O1),
                       EX.p2() => RDF.iri(EX.O2)
                     })
               }

      assert user
             |> Grax.add_additional_statements(%{
               EX.p1() => ~L"O1",
               EX.p3() => RDF.iri(EX.O3)
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => [RDF.iri(EX.User)],
                       EX.p1() => [RDF.iri(EX.O1), ~L"O1"],
                       EX.p2() => [RDF.iri(EX.O2)],
                       EX.p3() => [RDF.iri(EX.O3)]
                     })
               }
    end

    test "with coercible RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.add_additional_statements(%{
          EX.P1 => EX.O1,
          EX.P2 => EX.O2
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => [RDF.iri(EX.User)],
                       RDF.iri(EX.P1) => [RDF.iri(EX.O1)],
                       RDF.iri(EX.P2) => [RDF.iri(EX.O2)]
                     })
               }

      assert user
             |> Grax.add_additional_statements(%{
               EX.P1 => "O1",
               EX.P3 => 1
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => [RDF.iri(EX.User)],
                       RDF.iri(EX.P1) => [RDF.iri(EX.O1), ~L"O1"],
                       RDF.iri(EX.P2) => [RDF.iri(EX.O2)],
                       RDF.iri(EX.P3) => [RDF.XSD.integer(1)]
                     })
               }
    end

    test "rdf:type with Grax schema class is untouched" do
      assert Example.user(EX.User0)
             |> Grax.add_additional_statements(%{RDF.type() => RDF.iri(EX.Foo)}) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{RDF.type() => [RDF.iri(EX.User), RDF.iri(EX.Foo)]})
               }
    end
  end

  describe "Grax.put_additional_statements/2" do
    test "with RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.put_additional_statements(%{
          EX.p1() => EX.O1,
          EX.p2() => EX.O2
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => RDF.iri(EX.User),
                       EX.p1() => RDF.iri(EX.O1),
                       EX.p2() => RDF.iri(EX.O2)
                     })
               }

      assert user
             |> Grax.put_additional_statements(%{
               EX.p1() => ~L"O1",
               EX.p3() => RDF.iri(EX.O3)
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => [RDF.iri(EX.User)],
                       EX.p1() => [~L"O1"],
                       EX.p2() => [RDF.iri(EX.O2)],
                       EX.p3() => [RDF.iri(EX.O3)]
                     })
               }
    end

    test "with coercible RDF terms" do
      user =
        Example.user(EX.User0)
        |> Grax.put_additional_statements(%{
          EX.P1 => EX.O1,
          EX.P2 => EX.O2
        })

      assert user ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => RDF.iri(EX.User),
                       RDF.iri(EX.P1) => RDF.iri(EX.O1),
                       RDF.iri(EX.P2) => RDF.iri(EX.O2)
                     })
               }

      assert user
             |> Grax.put_additional_statements(%{
               EX.P1 => "O1",
               EX.P3 => 1
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => RDF.iri(EX.User),
                       RDF.iri(EX.P1) => ~L"O1",
                       RDF.iri(EX.P2) => RDF.iri(EX.O2),
                       RDF.iri(EX.P3) => RDF.XSD.integer(1)
                     })
               }
    end

    test "with additional statements from another schema" do
      assert Example.user(EX.User0)
             |> Grax.put_additional_statements(%{
               EX.P1 => EX.O1,
               EX.P2 => EX.O2
             })
             |> Grax.put_additional_statements(
               Example.user(EX.User1)
               |> Grax.put_additional_statements(%{
                 EX.P2 => EX.O3
               })
               |> Grax.additional_statements()
             ) ==
               Example.user(EX.User0)
               |> Grax.put_additional_statements(%{
                 EX.P1 => EX.O1,
                 EX.P2 => EX.O3
               })
    end

    test "rdf:type with Grax schema class can be overwritten" do
      assert Example.user(EX.User0)
             |> Grax.put_additional_statements(%{RDF.type() => RDF.iri(EX.Foo)}) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__: AdditionalStatements.new(%{RDF.type() => EX.Foo})
               }
    end
  end

  describe "Grax.delete_additional_statements/2" do
    test "with a map of predications" do
      user =
        Example.user(EX.User0)
        |> Grax.add_additional_statements(%{
          RDF.iri(EX.P1) => RDF.iri(EX.O1),
          EX.p2() => [RDF.iri(EX.O2), RDF.iri(EX.O3)]
        })

      assert Grax.delete_additional_statements(user, %{
               EX.p2() => RDF.iri(EX.O2)
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => [RDF.iri(EX.User)],
                       EX.P1 => [RDF.iri(EX.O1)],
                       EX.p2() => [RDF.iri(EX.O3)]
                     })
               }

      assert Grax.delete_additional_statements(user, %{
               EX.p2() => [RDF.iri(EX.O2), RDF.iri(EX.O3)]
             }) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => [RDF.iri(EX.User)],
                       RDF.iri(EX.P1) => [RDF.iri(EX.O1)]
                     })
               }

      assert Grax.delete_additional_statements(user, %{
               EX.p3() => RDF.iri(EX.O2)
             }) ==
               user

      assert Grax.delete_additional_statements(user, %{
               EX.P1 => EX.O1,
               EX.p2() => [EX.O2, EX.O3]
             }) ==
               Example.user(EX.User0)
    end

    test "rdf:type with Grax schema class can be deleted" do
      assert Example.user(EX.User0)
             |> Grax.delete_additional_statements(%{RDF.type() => RDF.iri(EX.User)}) ==
               %Example.User{Example.user(EX.User0) | __additional_statements__: %{}}
    end
  end

  describe "Grax.delete_additional_predicates/2" do
    test "with properties" do
      user =
        Example.user(EX.User0)
        |> Grax.add_additional_statements(%{
          RDF.iri(EX.P1) => RDF.iri(EX.O1),
          EX.p2() => [RDF.iri(EX.O2), RDF.iri(EX.O3)]
        })

      assert Grax.delete_additional_predicates(user, EX.p2()) ==
               %Example.User{
                 Example.user(EX.User0)
                 | __additional_statements__:
                     AdditionalStatements.new(%{
                       RDF.type() => [RDF.iri(EX.User)],
                       EX.P1 => [RDF.iri(EX.O1)]
                     })
               }

      assert Grax.delete_additional_predicates(user, EX.p3()) ==
               user

      assert Grax.delete_additional_predicates(user, [EX.P1, EX.p2()]) ==
               Example.user(EX.User0)
    end

    test "rdf:type with Grax schema class can be deleted" do
      assert Example.user(EX.User0)
             |> Grax.delete_additional_predicates(RDF.type()) ==
               %Example.User{Example.user(EX.User0) | __additional_statements__: %{}}
    end
  end

  describe "Grax.clear_additional_statements/1" do
    test "without opts" do
      assert Example.user(EX.User0)
             |> Grax.put_additional_statements(%{EX.P => EX.O})
             |> Grax.clear_additional_statements() == Example.user(EX.User0)
    end

    test "with clear_schema_class" do
      example =
        Example.user(EX.User0)
        |> Grax.put_additional_statements(%{EX.P => EX.O})
        |> Grax.clear_additional_statements(clear_schema_class: true)

      assert example.__additional_statements__ == Grax.Schema.AdditionalStatements.empty()
    end
  end
end
