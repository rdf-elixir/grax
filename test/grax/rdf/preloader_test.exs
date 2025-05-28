defmodule Grax.RDF.PreloaderTest do
  use Grax.TestCase

  alias Grax.RDF.Preloader
  alias Grax.ValidationError

  test "Grax.preload/2" do
    assert Example.user(EX.User0, depth: 0)
           |> Grax.preload(example_graph()) ==
             {:ok, Example.user(EX.User0, depth: 1)}

    graph =
      RDF.graph([
        EX.A |> EX.next(EX.B),
        EX.B |> EX.next(EX.C),
        EX.C |> EX.next(EX.D),
        EX.D |> EX.name("d")
      ])

    assert Example.DepthPreloading.build!(EX.A)
           |> Grax.preload(graph) ==
             Example.DepthPreloading.load(graph, EX.A)

    assert Example.AddDepthPreloading.build!(EX.A)
           |> Grax.preload(graph) ==
             Example.AddDepthPreloading.load(graph, EX.A)
  end

  describe "Grax.preload/3" do
    test "without errors" do
      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload(example_graph(), depth: 1) ==
               {:ok, Example.user(EX.User0, depth: 1)}

      assert Example.user(EX.User0, depth: 1)
             |> Grax.preload(example_graph(), depth: 1) ==
               {:ok, Example.user(EX.User0, depth: 1)}

      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload(example_graph(), depth: 2) ==
               {:ok, Example.user(EX.User0, depth: 2)}

      assert Example.user(EX.User0, depth: 1)
             |> Grax.preload(example_graph(), depth: 2) ==
               {:ok, Example.user(EX.User0, depth: 2)}
    end

    test "when no description of the linked resource exists in the graph" do
      # with on_missing_description: :empty_schema (default)
      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload(example_graph() |> Graph.delete_descriptions(EX.Post0)) ==
               {:ok,
                Example.user(EX.User0, depth: 1)
                |> Grax.put!(:posts, Example.Post.build!(EX.Post0))}

      # with on_missing_description: :use_rdf_node

      graph = RDF.graph([EX.A |> EX.user(EX.B)])

      assert Example.OnMissingDescription.build!(EX.A)
             |> Grax.preload(graph) ==
               Example.OnMissingDescription.build(EX.A, user: EX.B)
    end

    test "with validation errors" do
      graph_with_error = example_graph() |> Graph.add({EX.Post0, EX.title(), "Other"})

      assert {:error, %ValidationError{}} =
               Example.user(EX.User0, depth: 0)
               |> Grax.preload(graph_with_error, depth: 1)
    end
  end

  test "Grax.preload!/2" do
    assert Example.user(EX.User0, depth: 0)
           |> Grax.preload!(example_graph()) ==
             Example.user(EX.User0, depth: 1)

    graph =
      RDF.graph([
        EX.A |> EX.next(EX.B),
        EX.B |> EX.next(EX.C),
        EX.C |> EX.next(EX.D),
        EX.D |> EX.name("d")
      ])

    assert Example.DepthPreloading.build!(EX.A)
           |> Grax.preload!(graph) ==
             Example.DepthPreloading.load!(graph, EX.A)

    assert Example.AddDepthPreloading.build!(EX.A)
           |> Grax.preload!(graph) ==
             Example.AddDepthPreloading.load!(graph, EX.A)
  end

  describe "Grax.preload!/3" do
    test "without errors" do
      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload!(example_graph(), depth: 1) ==
               Example.user(EX.User0, depth: 1)
    end

    test "with validation errors" do
      graph_with_error = example_graph() |> Graph.add({EX.Post0, EX.title(), "Other"})

      post = Example.post(depth: 0)

      assert Example.user(EX.User0, depth: 0)
             |> Grax.preload!(graph_with_error) ==
               Example.user(EX.User0, depth: 1)
               |> Grax.put!(:posts, [Grax.put!(post, :title, [post.title, "Other"])])
    end
  end

  describe "Grax.preloaded?/1" do
    test "when one of the link properties is not preloaded" do
      refute Example.user(EX.User0, depth: 0) |> Grax.preloaded?()
      refute Example.post(depth: 0) |> Grax.preloaded?()
    end

    test "when all of the link properties are preloaded" do
      assert Example.user(EX.User0, depth: 1) |> Grax.preloaded?()
      assert Example.post(depth: 1) |> Grax.preloaded?()
    end
  end

  describe "Grax.preloaded?/2" do
    test "with preloaded link properties" do
      assert Example.user(EX.User0, depth: 1) |> Grax.preloaded?(:posts)
      assert Example.user(EX.User0, depth: 1) |> Grax.preloaded?(:comments)
      assert Example.post(depth: 1) |> Grax.preloaded?(:author)
      assert Example.post(depth: 1) |> Grax.preloaded?(:comments)
    end

    test "with the link has not preloaded values" do
      refute Example.user(EX.User0, depth: 0) |> Grax.preloaded?(:posts)
      refute Example.post(depth: 0) |> Grax.preloaded?(:author)
      refute Example.post(depth: 0) |> Grax.preloaded?(:comments)
    end

    test "with the link does not have values" do
      assert Example.user(EX.User0, depth: 0) |> Grax.preloaded?(:comments)
    end

    test "with data properties" do
      assert Example.user(EX.User0, depth: 0) |> Grax.preloaded?(:name)
      assert Example.post(depth: 0) |> Grax.preloaded?(:title)
    end

    test "with non-existing properties" do
      assert_raise ArgumentError, fn ->
        Example.post(depth: 0) |> Grax.preloaded?(:not_existing)
      end
    end
  end

  describe "implicit preloading via load" do
    test "when no description of the linked resource exists" do
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

    test "link to itself without circle" do
      assert RDF.graph([
               EX.A |> EX.name("a") |> EX.next(EX.B),
               EX.B |> EX.name("b") |> EX.next(EX.C),
               EX.C |> EX.name("c")
             ])
             |> Example.SelfLinked.load(EX.A) ==
               Example.SelfLinked.build(EX.A,
                 name: "a",
                 next: Example.SelfLinked.build!(EX.B, name: "b", next: RDF.iri(EX.C))
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
                 next: Example.SelfLinked.build!(~B"b", name: "b", next: ~B"c")
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
                     next: Example.SelfLinked.build!(~B"c", name: "c")
                   )
               )
    end

    test "ordered lists" do
      elements = [Example.user(EX.User0), Example.user(EX.User1)]
      ids = Enum.map(elements, & &1.__id__)
      list = RDF.List.from(ids)

      assert Graph.new()
             |> Graph.add({EX.S, EX.users(), list.head})
             |> Graph.add(list.graph)
             |> Graph.add(Enum.map(elements, &Grax.to_rdf!/1))
             |> Graph.add(EX.Comment1 |> Example.comment() |> Grax.to_rdf!())
             |> Example.RdfListType.load(EX.S) ==
               Example.RdfListType.build(EX.S, users: elements)

      assert Graph.new()
             |> Graph.add({EX.S, EX.users(), list.head})
             |> Graph.add(list.graph)
             |> Example.RdfListType.load(EX.S) ==
               Example.RdfListType.build(EX.S, users: ids)
    end

    test "direct link to itself" do
      assert RDF.graph([EX.A |> EX.name("a") |> EX.next(EX.A)])
             |> Example.SelfLinked.load(EX.A) ==
               Example.SelfLinked.build(EX.A, name: "a", next: RDF.iri(EX.A))
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
                     link1: [
                       Example.Circle.build!(EX.C, name: "c", link1: RDF.iri(EX.A))
                     ]
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
                             link1: [Example.Circle.build!(EX.E, name: "e", link1: RDF.iri(EX.B))]
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
                             link1: [Example.Circle.build!(EX.D, name: "d", link1: RDF.iri(EX.C))]
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
                             link1: [Example.Circle.build!(EX.E, name: "e", link2: RDF.iri(EX.B))]
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
                             link1: [Example.Circle.build!(EX.D, name: "d", link2: RDF.iri(EX.C))]
                           )
                         ]
                       )
                     ]
                   )
                 ]
               )
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
                     next: Example.DepthPreloading.build!(EX.C, next: RDF.iri(EX.D))
                   )
               )
    end

    test "zero depth preloading" do
      assert RDF.graph([
               EX.A |> EX.zero(EX.User0),
               example_description(:user)
             ])
             |> Example.ZeroDepthLinkPreloading.load(EX.A) ==
               Example.ZeroDepthLinkPreloading.build(EX.A,
                 zero: RDF.iri(EX.User0)
               )

      assert RDF.graph([
               EX.A |> EX.user(EX.User0),
               example_description(:user)
             ])
             |> Example.ZeroDepthPreloading.load(EX.A) ==
               Example.ZeroDepthPreloading.build(EX.A,
                 user: RDF.iri(EX.User0)
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

    test "overridden build/2 is used" do
      assert RDF.graph(EX.A |> EX.preloaded(EX.B))
             |> Example.OverrideBuild.load(EX.A) ==
               {:ok,
                %Example.OverrideBuild{
                  __id__: RDF.iri(EX.A),
                  foo: "overridden foo",
                  bar: "bar",
                  preloaded: %Example.OverrideBuild{
                    __id__: RDF.iri(EX.B),
                    foo: "overridden foo",
                    bar: "bar"
                  }
                }}
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
                               Example.Circle.build!(EX.B, name: "b", link1: RDF.iri(EX.C))
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
                                 link1: [
                                   Example.Circle.build!(EX.B, name: "b", link1: RDF.iri(EX.D))
                                 ]
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
                                 link1: [
                                   Example.Circle.build!(EX.C, name: "c", link1: RDF.iri(EX.E))
                                 ]
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
               "expected result for {#{inspect(depth)}, #{inspect(max_depth)}, #{inspect(preload_spec)}} is #{inspect(expected_result)} but gut #{inspect(result)}"
      end)
    end

    test "from general schema preload spec" do
      %{
        {0, nil, Example.AddDepthPreloading} => {true, nil, 3},
        {0, 0, Example.AddDepthPreloading} => {true, nil, 3},
        {0, 1, Example.AddDepthPreloading} => {true, nil, 3},
        {0, 4, Example.AddDepthPreloading} => {true, nil, 3},
        {1, 0, Example.AddDepthPreloading} => {true, nil, 4},
        {1, 1, Example.AddDepthPreloading} => {true, nil, 4},
        {1, 5, Example.AddDepthPreloading} => {true, nil, 4}
      }
      |> Enum.each(fn {{depth, max_depth, schema}, expected_result} ->
        result = Preloader.next_preload_opt(nil, nil, schema, :next, depth, max_depth)

        assert result == expected_result,
               "expected result for {#{inspect(depth)}, #{inspect(max_depth)}, #{inspect(schema)}} is #{inspect(expected_result)} but gut #{inspect(result)}"
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
               "expected result for {#{inspect(depth)}, #{inspect(max_depth)}} is #{inspect(expected_result)} but gut #{inspect(result)}"
      end)
    end
  end
end
