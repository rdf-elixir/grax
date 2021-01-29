defmodule Grax.RDF.PreloaderTest do
  use Grax.TestCase

  alias Grax.RDF.Preloader
  alias Grax.InvalidResourceTypeError

  test "link to itself without circle" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(EX.B),
             EX.B |> EX.name("b") |> EX.next(EX.C),
             EX.C |> EX.name("c")
           ])
           |> Example.SelfLinked.load(EX.A) ==
             Example.SelfLinked.build(EX.A,
               name: "a",
               next: Example.SelfLinked.build!(EX.B, name: "b")
             )
  end

  test "link via blank node" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(~B"b"),
             ~B"b" |> EX.name("b") |> EX.next(~B"c"),
             ~B"c" |> EX.name("c")
           ])
           |> Example.SelfLinked.load(EX.A) ==
             Example.SelfLinked.build(EX.A,
               name: "a",
               next: Example.SelfLinked.build!(~B"b", name: "b")
             )

    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.next(~B"b"),
             ~B"b" |> EX.name("b") |> EX.next(~B"c"),
             ~B"c" |> EX.name("c")
           ])
           |> Example.SelfLinked.load(EX.A, depth: 3) ==
             Example.SelfLinked.build(EX.A,
               name: "a",
               next:
                 Example.SelfLinked.build!(~B"b",
                   name: "b",
                   next: Example.SelfLinked.build!(~B"c", name: "c", next: nil)
                 )
             )
  end

  test "direct link to itself" do
    assert RDF.graph([EX.A |> EX.name("a") |> EX.next(EX.A)])
           |> Example.SelfLinked.load(EX.A) ==
             Example.SelfLinked.build(EX.A, name: "a")
  end

  test "link to itself with circle" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.link1(EX.B),
             EX.B |> EX.name("b") |> EX.link1(EX.C),
             EX.C |> EX.name("c") |> EX.link1(EX.A)
           ])
           |> Example.Circle.load(EX.A) ==
             Example.Circle.build(EX.A,
               name: "a",
               link2: [],
               link1: [
                 Example.Circle.build!(EX.B,
                   name: "b",
                   link2: [],
                   link1: [Example.Circle.build!(EX.C, name: "c", link2: [])]
                 )
               ]
             )
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
             Example.Circle.build(EX.A,
               name: "a",
               link2: [],
               link1: [
                 Example.Circle.build!(EX.B,
                   name: "b",
                   link2: [],
                   link1: [
                     Example.Circle.build!(EX.D,
                       name: "d",
                       link2: [],
                       link1: [
                         Example.Circle.build!(EX.C,
                           name: "c",
                           link2: [],
                           link1: [Example.Circle.build!(EX.E, name: "e", link2: [])]
                         )
                       ]
                     )
                   ]
                 ),
                 Example.Circle.build!(EX.C,
                   name: "c",
                   link2: [],
                   link1: [
                     Example.Circle.build!(EX.E,
                       name: "e",
                       link2: [],
                       link1: [
                         Example.Circle.build!(EX.B,
                           name: "b",
                           link2: [],
                           link1: [Example.Circle.build!(EX.D, name: "d", link2: [])]
                         )
                       ]
                     )
                   ]
                 )
               ]
             )
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
             Example.Circle.build(EX.A,
               name: "a",
               link2: [],
               link1: [
                 Example.Circle.build!(EX.B,
                   name: "b",
                   link2: [],
                   link1: [
                     Example.Circle.build!(EX.D,
                       name: "d",
                       link1: [],
                       link2: [
                         Example.Circle.build!(EX.C,
                           name: "c",
                           link2: [],
                           link1: [Example.Circle.build!(EX.E, name: "e", link1: [])]
                         )
                       ]
                     )
                   ]
                 ),
                 Example.Circle.build!(EX.C,
                   name: "c",
                   link2: [],
                   link1: [
                     Example.Circle.build!(EX.E,
                       name: "e",
                       link1: [],
                       link2: [
                         Example.Circle.build!(EX.B,
                           name: "b",
                           link2: [],
                           link1: [Example.Circle.build!(EX.D, name: "d", link1: [])]
                         )
                       ]
                     )
                   ]
                 )
               ]
             )
  end

  describe "links with multiple schemas" do
    test "when a class matches" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Post1) |> EX.strictOne(EX.Post1),
               EX.Post1 |> RDF.type(EX.Post) |> EX.title("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: Example.Post.build!(EX.Post1, title: "foo"),
                 strict_one: Example.Post.build!(EX.Post1, title: "foo"),
                 many: []
               )

      assert RDF.graph([
               EX.A |> EX.one(EX.Comment1) |> EX.strictOne(EX.Comment1),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: Example.Comment.build!(EX.Comment1, content: "foo"),
                 strict_one: Example.Comment.build!(EX.Comment1, content: "foo"),
                 many: []
               )

      assert RDF.graph([
               EX.A |> EX.many(EX.Comment1),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [Example.Comment.build!(EX.Comment1, content: "foo")]
               )
    end

    test "fallback" do
      assert RDF.graph([
               EX.A |> EX.many(EX.Post1),
               EX.Post1 |> EX.title("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [Example.Post.build!(EX.Post1, title: "foo")]
               )

      assert RDF.graph([
               EX.A |> EX.many(EX.Post1) |> EX.many(EX.Comment1),
               EX.Post1 |> RDF.type(EX.Other) |> EX.title("foo"),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: [
                   Example.Comment.build!(EX.Comment1, content: "foo"),
                   Example.Post.build!(EX.Post1, title: "foo")
                 ]
               )
    end

    test "when no class matches with non-strict matching" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Something)
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: []
               )

      assert RDF.graph([
               EX.A |> EX.one(EX.Something1) |> EX.one(EX.Something21),
               EX.Something1 |> EX.foo("foo"),
               EX.Something2 |> RDF.type(EX.Other) |> EX.bar("bar")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: nil,
                 strict_one: nil,
                 many: []
               )
    end

    test "when some classes don't match with non-strict matching" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Something1) |> EX.one(EX.Comment1),
               EX.Something1 |> EX.foo("foo"),
               EX.Comment1 |> RDF.type(EX.Comment) |> EX.content("bar")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               Example.HeterogeneousLinks.build(EX.A,
                 one: Example.Comment.build!(EX.Comment1, content: "bar"),
                 strict_one: nil,
                 many: []
               )
    end

    test "when no class matches with strict matching" do
      assert RDF.graph([
               EX.A |> EX.strictOne(EX.Post1),
               EX.Post1 |> EX.title("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               {:error, InvalidResourceTypeError.exception(type: :no_match, resource_types: [])}
    end

    test "when multiple class are matching" do
      assert RDF.graph([
               EX.A |> EX.one(EX.Post1),
               EX.Post1 |> RDF.type([EX.Post, EX.Comment]) |> EX.title("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [RDF.iri(EX.Comment), RDF.iri(EX.Post)]
                )}

      assert RDF.graph([
               EX.A |> EX.strictOne(EX.Post1),
               EX.Post1 |> RDF.type([EX.Post, EX.Comment]) |> EX.title("foo")
             ])
             |> Example.HeterogeneousLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :multiple_matches,
                  resource_types: [RDF.iri(EX.Comment), RDF.iri(EX.Post)]
                )}
    end
  end

  test "depth preloading" do
    assert RDF.graph([
             EX.A |> EX.next(EX.B),
             EX.B |> EX.next(EX.C),
             EX.C |> EX.next(EX.D),
             EX.D |> EX.name("d")
           ])
           |> Example.DepthPreloading.load(EX.A) ==
             Example.DepthPreloading.build(EX.A,
               next:
                 Example.DepthPreloading.build!(EX.B,
                   next: Example.DepthPreloading.build!(EX.C)
                 )
             )
  end

  test "manual preload control" do
    assert Example.User.load(example_graph(), EX.User0, depth: 1) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    assert Example.User.load(example_graph(), EX.User0, depth: 2) ==
             {:ok, Example.user(EX.User0, depth: 2)}

    assert Example.User.load(example_graph(), EX.User0, depth: 3) ==
             {:ok, Example.user(EX.User0, depth: 3)}
  end

  test "with preload opt no circle check is performed" do
    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.link1(EX.B),
             EX.B |> EX.name("b") |> EX.link1(EX.C),
             EX.C |> EX.name("c") |> EX.link1(EX.A)
           ])
           |> Example.Circle.load(EX.A, depth: 4) ==
             Example.Circle.build(EX.A,
               name: "a",
               link2: [],
               link1: [
                 Example.Circle.build!(EX.B,
                   name: "b",
                   link2: [],
                   link1: [
                     Example.Circle.build!(EX.C,
                       name: "c",
                       link2: [],
                       link1: [
                         Example.Circle.build!(EX.A,
                           name: "a",
                           link2: [],
                           link1: [
                             Example.Circle.build!(EX.B, name: "b")
                           ]
                         )
                       ]
                     )
                   ]
                 )
               ]
             )

    assert RDF.graph([
             EX.A |> EX.name("a") |> EX.link1(EX.B, EX.C),
             EX.B |> EX.name("b") |> EX.link1(EX.D),
             EX.C |> EX.name("c") |> EX.link1(EX.E),
             EX.D |> EX.name("d") |> EX.link1(EX.C),
             EX.E |> EX.name("e") |> EX.link1(EX.B)
           ])
           |> Example.Circle.load(EX.A, depth: 5) ==
             Example.Circle.build(EX.A,
               name: "a",
               link2: [],
               link1: [
                 Example.Circle.build!(EX.B,
                   name: "b",
                   link2: [],
                   link1: [
                     Example.Circle.build!(EX.D,
                       name: "d",
                       link2: [],
                       link1: [
                         Example.Circle.build!(EX.C,
                           name: "c",
                           link2: [],
                           link1: [
                             Example.Circle.build!(EX.E,
                               name: "e",
                               link2: [],
                               link1: [Example.Circle.build!(EX.B, name: "b")]
                             )
                           ]
                         )
                       ]
                     )
                   ]
                 ),
                 Example.Circle.build!(EX.C,
                   name: "c",
                   link2: [],
                   link1: [
                     Example.Circle.build!(EX.E,
                       name: "e",
                       link2: [],
                       link1: [
                         Example.Circle.build!(EX.B,
                           name: "b",
                           link2: [],
                           link1: [
                             Example.Circle.build!(EX.D,
                               name: "d",
                               link2: [],
                               link1: [Example.Circle.build!(EX.C, name: "c")]
                             )
                           ]
                         )
                       ]
                     )
                   ]
                 )
               ]
             )
  end

  describe "next_preload_opt" do
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
end
