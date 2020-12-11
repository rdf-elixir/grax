defmodule RDF.Mapping.Link.PreloaderTest do
  use RDF.Mapping.TestCase

  alias RDF.Mapping.Link.Preloader

  test "link to itself without circle" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(EX.B),
             EX.B |> EX.name("b") |> EX.next(EX.C),
             EX.C |> EX.name("c")
           ])
           |> Example.SelfLinked.load(EX.A) ==
             {:ok,
              %Example.SelfLinked{
                __iri__: IRI.to_string(EX.A),
                name: "a",
                next: %Example.SelfLinked{
                  __iri__: IRI.to_string(EX.B),
                  name: "b"
                }
              }}
  end

  test "direct link to itself" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(EX.A)
           ])
           |> Example.SelfLinked.load(EX.A) ==
             {:ok, %Example.SelfLinked{__iri__: IRI.to_string(EX.A), name: "a"}}
  end

  test "link to itself with circle" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.link1(EX.B),
             EX.B |> EX.name("b") |> EX.link1(EX.C),
             EX.C |> EX.name("c") |> EX.link1(EX.A)
           ])
           |> Example.Circle.load(EX.A) ==
             {:ok,
              %Example.Circle{
                __iri__: IRI.to_string(EX.A),
                name: "a",
                link2: [],
                link1: [
                  %Example.Circle{
                    __iri__: IRI.to_string(EX.B),
                    name: "b",
                    link2: [],
                    link1: [
                      %Example.Circle{
                        __iri__: IRI.to_string(EX.C),
                        name: "c",
                        link2: []
                      }
                    ]
                  }
                ]
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
           |> Example.Circle.load(EX.A) ==
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
           |> Example.Circle.load(EX.A) ==
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
           |> Example.DepthPreloading.load(EX.A) ==
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

  test "manual preload control" do
    assert RDF.graph([
             EX.A |> EX.next(EX.B),
             EX.B |> EX.next(EX.C),
             EX.C |> EX.next(EX.D),
             EX.D |> EX.name("d")
           ])
           |> Example.DepthPreloading.load(EX.A, preload: [next: true]) ==
             {:ok,
              %Example.DepthPreloading{
                __iri__: IRI.to_string(EX.A),
                next: %Example.DepthPreloading{
                  __iri__: IRI.to_string(EX.B),
                  next: %Example.DepthPreloading{
                    __iri__: IRI.to_string(EX.C)
                  }
                }
              }}

    assert Example.User.load(example_graph(), EX.User0, preload: false) ==
             {:ok, Example.user(EX.User0, depth: 0)}

    assert Example.User.load(example_graph(), EX.User0, preload: true) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, preload: 1) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, preload: 2) ==
             {:ok, Example.user(EX.User0, depth: 2)}

    assert Example.User.load(example_graph(), EX.User0, preload: 3) ==
             {:ok, Example.user(EX.User0, depth: 3)}

    assert Example.User.load(example_graph(), EX.User0, preload: :other) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, preload: [posts: false]) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, preload: :posts) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, preload: [:posts]) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, preload: [posts: true]) ==
             {:ok, Example.user(EX.User0, depth: 2)}

    assert Example.User.load(example_graph(), EX.User0, preload: [posts: 1]) ==
             {:ok, Example.user(EX.User0, depth: 2)}

    assert Example.User.load(example_graph(), EX.User0, preload: [posts: 2]) ==
             {:ok, Example.user(EX.User0, depth: 3)}

    assert Example.User.load(example_graph(), EX.User0, preload: [posts: :other]) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, preload: [posts: :comments]) ==
             {:ok, Example.user(EX.User0, depth: 2)}
  end

  describe "next_preload_opt" do
    test "from preload opt" do
      %{
        {0, false} => {false, {:depth, 0}, 0},
        {0, true} => {true, {:depth, 1}, 1},
        {0, 2} => {true, {:depth, 2}, 2},
        {1, false} => {false, {:depth, 1}, 1},
        {1, true} => {true, {:depth, 2}, 2},
        {1, 2} => {true, {:depth, 3}, 3}
      }
      |> Enum.each(fn {{depth, preload_opt}, expected_result} ->
        result =
          Preloader.next_preload_opt(
            preload_opt,
            nil,
            Example.AddDepthPreloading,
            :next,
            depth,
            nil
          )

        assert result == expected_result,
               "expected result for {#{inspect(depth)}, #{inspect(preload_opt)}} is #{
                 inspect(expected_result)
               } but gut #{inspect(result)}"
      end)
    end

    test "from preload opt in Ecto-style" do
      %{
        {0, nil, :next, :next, {:depth, 5}} => {true, {:depth, 1}, 5},
        {0, nil, :next, [:next], {:depth, 5}} => {true, {:depth, 1}, 5},
        {0, nil, :next, [:other, :next], {:depth, 5}} => {true, {:depth, 1}, 5},
        {0, nil, :next, [next: false], {:depth, 5}} => {true, {:depth, 1}, 5},
        {0, nil, :next, [next: true], {:depth, 5}} => {true, {:depth, 2}, 5},
        {0, nil, :next, [next: 4], {:depth, 5}} => {true, {:depth, 5}, 5},
        {0, nil, :next, [next: :foo], {:depth, 5}} => {true, :foo, 5},
        {0, nil, :next, [next: [:foo, :bar]], {:depth, 5}} => {true, [:foo, :bar], 5},
        {0, nil, :next, [next: [foo: [:bar]]], {:depth, 5}} => {true, [foo: [:bar]], 5},
        {1, 1, :next, :next, {:depth, 5}} => {true, {:depth, 2}, 2},
        {1, 1, :next, [:next], {:add_depth, 5}} => {true, {:depth, 2}, 6},
        {1, 1, :next, [:other, :next], {:depth, 5}} => {true, {:depth, 2}, 2},
        {1, 1, :next, [next: true], {:depth, 5}} => {true, {:depth, 3}, 3},
        {1, 1, :next, [next: 4], {:depth, 5}} => {true, {:depth, 6}, 6},
        {1, 1, :next, [next: :foo], {:depth, 5}} => {true, :foo, 1},
        {1, 1, :next, [next: [:foo, :bar]], {:depth, 5}} => {true, [:foo, :bar], 1},
        {1, 1, :next, [next: [foo: [:bar]]], {:depth, 5}} => {true, [foo: [:bar]], 1},
        # spec-fallback cases
        {0, nil, :next, :other, {:depth, 42}} => {true, nil, 42},
        {0, nil, :next, :other, {:add_depth, 42}} => {true, nil, 42},
        {1, 2, :next, :other, {:depth, 42}} => {true, nil, 2},
        {1, 2, :next, :other, {:add_depth, 42}} => {true, nil, 43}
      }
      |> Enum.each(fn {{depth, max_depth, link, preload_opt, preload_spec}, expected_result} ->
        result =
          Preloader.next_preload_opt(
            preload_opt,
            preload_spec,
            Example.AddDepthPreloading,
            link,
            depth,
            max_depth
          )

        assert result == expected_result,
               "expected result for {#{inspect(depth)}, #{inspect(max_depth)}, #{inspect(link)}, #{
                 inspect(preload_opt)
               }, #{inspect(preload_spec)}} is #{inspect(expected_result)} but gut #{
                 inspect(result)
               }"
      end)
    end

    test "from link-specific preload spec" do
      %{
        {0, nil, {:depth, 2}} => {true, nil, 2},
        {0, nil, {:add_depth, 2}} => {true, nil, 2},
        {0, 42, {:depth, 2}} => {true, nil, 2},
        {0, 42, {:add_depth, 2}} => {true, nil, 2},
        {1, 0, {:depth, 2}} => {false, nil, 0},
        {1, 0, {:add_depth, 2}} => {true, nil, 3},
        {1, 1, {:depth, 2}} => {false, nil, 1},
        {1, 1, {:add_depth, 2}} => {true, nil, 3},
        {1, 2, {:depth, 2}} => {true, nil, 2},
        {1, 2, {:add_depth, 2}} => {true, nil, 3}
      }
      |> Enum.each(fn {{depth, max_depth, preload_spec}, expected_result} ->
        # we're setting an invalid mapping module here on purpose, to ensure it's not attempted to use its defaults
        result = Preloader.next_preload_opt(nil, preload_spec, Example, :next, depth, max_depth)

        assert result == expected_result,
               "expected result for {#{inspect(depth)}, #{inspect(max_depth)}, #{
                 inspect(preload_spec)
               }} is #{inspect(expected_result)} but gut #{inspect(result)}"
      end)
    end

    test "from general mapping preload spec" do
      %{
        {0, nil, Example.AddDepthPreloading} => {true, nil, 3},
        {0, 0, Example.AddDepthPreloading} => {true, nil, 3},
        {0, 1, Example.AddDepthPreloading} => {true, nil, 3},
        {0, 4, Example.AddDepthPreloading} => {true, nil, 3},
        {1, 0, Example.AddDepthPreloading} => {true, nil, 4},
        {1, 1, Example.AddDepthPreloading} => {true, nil, 4},
        {1, 5, Example.AddDepthPreloading} => {true, nil, 4}
      }
      |> Enum.each(fn {{depth, max_depth, mapping_mod}, expected_result} ->
        result = Preloader.next_preload_opt(nil, nil, mapping_mod, :next, depth, max_depth)

        assert result == expected_result,
               "expected result for {#{inspect(depth)}, #{inspect(max_depth)}, #{
                 inspect(mapping_mod)
               }} is #{inspect(expected_result)} but gut #{inspect(result)}"
      end)
    end

    test "from default" do
      %{
        {0, nil} => {true, nil, 1},
        {0, 0} => {true, nil, 1},
        {0, 1} => {true, nil, 1},
        {1, 0} => {false, nil, 0},
        {1, 1} => {false, nil, 1},
        {1, 2} => {true, nil, 2}
      }
      |> Enum.each(fn {{depth, max_depth}, expected_result} ->
        result = Preloader.next_preload_opt(nil, nil, Example.User, :next, depth, max_depth)

        assert result == expected_result,
               "expected result for {#{inspect(depth)}, #{inspect(max_depth)}} is #{
                 inspect(expected_result)
               } but gut #{inspect(result)}"
      end)
    end
  end

  describe "preload_opt" do
    test "general preloading opts" do
      assert Preloader.preload_opt(:foo, nil) == nil
      assert Preloader.preload_opt(:foo, false) == {:add_depth, 0}
      assert Preloader.preload_opt(:foo, true) == {:add_depth, 1}
      assert Preloader.preload_opt(:foo, 42) == {:add_depth, 42}
    end

    test "set default preloading for specific link" do
      assert Preloader.preload_opt(:foo, foo: true) == {:add_depth, 2}
      assert Preloader.preload_opt(:foo, foo: false) == {:add_depth, 1}
      assert Preloader.preload_opt(:foo, foo: 2) == {:add_depth, 3}

      assert Preloader.preload_opt(:foo, bar: true) == nil
      assert Preloader.preload_opt(:foo, bar: 2) == nil
    end

    test "Ecto-style" do
      assert Preloader.preload_opt(:foo, foo: [bar: true]) == [bar: true]
      assert Preloader.preload_opt(:foo, foo: :bar) == :bar
      assert Preloader.preload_opt(:foo, foo: [:bar]) == [:bar]
      assert Preloader.preload_opt(:foo, :bar) == nil
      assert Preloader.preload_opt(:foo, [:foo, :bar]) == {:add_depth, 1}
      assert Preloader.preload_opt(:foo, [:bar, :baz]) == nil
    end
  end
end
