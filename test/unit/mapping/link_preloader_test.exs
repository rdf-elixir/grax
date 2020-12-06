defmodule RDF.Mapping.Link.PreloaderTest do
  use RDF.Test.Case

  test "link to itself without circle" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(EX.B),
             EX.B |> EX.name("b") |> EX.next(EX.C),
             EX.C |> EX.name("c")
           ])
           |> Example.SelfLinked.from_rdf(EX.A) ==
             {:ok,
              %Example.SelfLinked{
                __iri__: IRI.to_string(EX.A),
                name: "a",
                next: %Example.SelfLinked{
                  __iri__: IRI.to_string(EX.B),
                  name: "b",
                  next: %Example.SelfLinked{
                    __iri__: IRI.to_string(EX.C),
                    name: "c",
                    next: nil
                  }
                }
              }}
  end

  test "direct link to itself" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(EX.A)
           ])
           |> Example.SelfLinked.from_rdf(EX.A) ==
             {:ok, %Example.SelfLinked{__iri__: IRI.to_string(EX.A), name: "a"}}
  end

  test "link to itself with circle" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(EX.B),
             EX.B |> EX.name("b") |> EX.next(EX.C),
             EX.C |> EX.name("c") |> EX.next(EX.A)
           ])
           |> Example.SelfLinked.from_rdf(EX.A) ==
             {:ok,
              %Example.SelfLinked{
                __iri__: IRI.to_string(EX.A),
                name: "a",
                next: %Example.SelfLinked{
                  __iri__: IRI.to_string(EX.B),
                  name: "b",
                  next: %Example.SelfLinked{
                    __iri__: IRI.to_string(EX.C),
                    name: "c"
                  }
                }
              }}
  end

  test "indirect circle" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.link1(EX.B, EX.C),
             EX.B |> EX.name("b") |> EX.link1(EX.D),
             EX.C |> EX.name("c") |> EX.link1(EX.E),
             EX.D |> EX.name("d") |> EX.link1(EX.C),
             EX.E |> EX.name("e") |> EX.link1(EX.B)
           ])
           |> Example.Circle.from_rdf(EX.A) ==
             {
               :ok,
               %Example.Circle{
                 __iri__: "http://example.com/A",
                 name: "a",
                 link2: [],
                 link1: [
                   %Example.Circle{
                     __iri__: "http://example.com/B",
                     name: "b",
                     link2: [],
                     link1: [
                       %Example.Circle{
                         __iri__: "http://example.com/D",
                         name: "d",
                         link2: [],
                         link1: [
                           %Example.Circle{
                             __iri__: "http://example.com/C",
                             name: "c",
                             link2: [],
                             link1: [
                               %Example.Circle{
                                 __iri__: "http://example.com/E",
                                 name: "e",
                                 link2: []
                               }
                             ]
                           }
                         ]
                       }
                     ]
                   },
                   %Example.Circle{
                     __iri__: "http://example.com/C",
                     name: "c",
                     link2: [],
                     link1: [
                       %Example.Circle{
                         __iri__: "http://example.com/E",
                         name: "e",
                         link2: [],
                         link1: [
                           %Example.Circle{
                             __iri__: "http://example.com/B",
                             name: "b",
                             link2: [],
                             link1: [
                               %Example.Circle{
                                 __iri__: "http://example.com/D",
                                 name: "d",
                                 link2: []
                               }
                             ]
                           }
                         ]
                       }
                     ]
                   }
                 ]
               }
             }
  end

  test "indirect circle over different properties" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.link1(EX.B, EX.C),
             EX.B |> EX.name("b") |> EX.link1(EX.D),
             EX.C |> EX.name("c") |> EX.link1(EX.E),
             EX.D |> EX.name("d") |> EX.link2(EX.C),
             EX.E |> EX.name("e") |> EX.link2(EX.B)
           ])
           |> Example.Circle.from_rdf(EX.A) ==
             {
               :ok,
               %Example.Circle{
                 __iri__: "http://example.com/A",
                 name: "a",
                 link2: [],
                 link1: [
                   %Example.Circle{
                     __iri__: "http://example.com/B",
                     name: "b",
                     link2: [],
                     link1: [
                       %Example.Circle{
                         __iri__: "http://example.com/D",
                         name: "d",
                         link1: [],
                         link2: [
                           %Example.Circle{
                             __iri__: "http://example.com/C",
                             name: "c",
                             link2: [],
                             link1: [
                               %Example.Circle{
                                 __iri__: "http://example.com/E",
                                 name: "e",
                                 link1: []
                               }
                             ]
                           }
                         ]
                       }
                     ]
                   },
                   %Example.Circle{
                     __iri__: "http://example.com/C",
                     name: "c",
                     link2: [],
                     link1: [
                       %Example.Circle{
                         __iri__: "http://example.com/E",
                         name: "e",
                         link1: [],
                         link2: [
                           %Example.Circle{
                             __iri__: "http://example.com/B",
                             name: "b",
                             link2: [],
                             link1: [
                               %Example.Circle{
                                 __iri__: "http://example.com/D",
                                 name: "d",
                                 link1: []
                               }
                             ]
                           }
                         ]
                       }
                     ]
                   }
                 ]
               }
             }
  end

  test "depth preloading" do
    assert RDF.graph([
             EX.A |> EX.next(EX.B),
             EX.B |> EX.next(EX.C),
             EX.C |> EX.next(EX.D),
             EX.D |> EX.name("d")
           ])
           |> Example.DepthPreloading.from_rdf(EX.A) ==
             {:ok,
              %Example.DepthPreloading{
                __iri__: IRI.to_string(EX.A),
                next: %Example.DepthPreloading{
                  __iri__: IRI.to_string(EX.B),
                  next: %Example.DepthPreloading{
                    __iri__: "http://example.com/C"
                  }
                }
              }}
  end
end
