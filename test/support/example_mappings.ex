defmodule Example do
  alias Example.NS.EX
  alias RDF.{IRI, Description, Graph}

  import ExUnit.Assertions

  @compile {:no_warn_undefined, Example.NS.EX}

  defmodule User do
    use Grax

    schema EX.User do
      property name: EX.name(), type: :string
      property email: EX.email(), type: [:string]
      property age: EX.age(), type: :integer
      property password: nil

      property customer_type: RDF.type(),
               from_rdf: :customer_type_from_rdf,
               to_rdf: :customer_type_to_rdf

      link posts: EX.post(), type: [Example.Post]
      link comments: EX.comment(), type: [Example.Comment]

      def customer_type_from_rdf(types, _description, _graph) do
        {:ok, if(RDF.iri(EX.PremiumUser) in types, do: :premium_user)}
      end

      def customer_type_to_rdf(:premium_user, _user), do: {:ok, EX.PremiumUser}
      def customer_type_to_rdf(_, _), do: {:ok, nil}
    end
  end

  defmodule Post do
    use Grax

    schema EX.Post do
      property title: EX.title(), type: :string
      property content: EX.content(), type: :string
      link author: EX.author(), type: Example.User
      link comments: EX.comment(), type: [Example.Comment]
    end
  end

  defmodule Comment do
    use Grax

    schema EX.Comment do
      property content: EX.content(), type: :string
      link about: EX.about(), type: Example.Post
      link author: EX.author(), type: Example.User
    end
  end

  def user(id, opts \\ [depth: 1])

  def user(EX.User0, depth: 0) do
    %Example.User{
      __id__: IRI.new(EX.User0),
      name: "John Doe",
      age: 42,
      email: ~w[jd@example.com john@doe.com],
      customer_type: :premium_user
    }
  end

  def user(EX.User1, depth: 0) do
    %Example.User{
      __id__: IRI.new(EX.User1),
      name: "Erika Mustermann",
      email: ["erika@mustermann.de"]
    }
  end

  def user(EX.User2, depth: 0) do
    %Example.User{
      __id__: IRI.new(EX.User2),
      name: "Max Mustermann",
      email: ["max@mustermann.de"]
    }
  end

  def user(EX.User0, depth: depth) do
    %Example.User{user(EX.User0, depth: 0) | posts: [post(depth: depth - 1)], comments: []}
  end

  def post(opts \\ [depth: 1])

  def post(depth: 0) do
    %Example.Post{
      __id__: IRI.new(EX.Post0),
      title: "Lorem ipsum",
      content: "Lorem ipsum dolor sit amet, …"
    }
  end

  def post(depth: depth) do
    %Example.Post{
      post(depth: 0)
      | comments: comments(depth: depth - 1),
        author: user(EX.User0, depth: depth - 1)
    }
  end

  def comments(depth: depth) do
    [comment(EX.Comment1, depth: depth), comment(EX.Comment2, depth: depth)]
  end

  def comment(EX.Comment1, depth: 0) do
    %Example.Comment{
      __id__: IRI.new(EX.Comment1),
      content: "First"
    }
  end

  def comment(EX.Comment2, depth: 0) do
    %Example.Comment{
      __id__: IRI.new(EX.Comment2),
      content: "Second"
    }
  end

  def comment(EX.Comment1, depth: depth) do
    %Example.Comment{
      comment(EX.Comment1, depth: 0)
      | author: user(EX.User1, depth: depth - 1),
        about: post(depth: depth - 1)
    }
  end

  def comment(EX.Comment2, depth: depth) do
    %Example.Comment{
      comment(EX.Comment2, depth: 0)
      | author: user(EX.User2, depth: depth - 1),
        about: post(depth: depth - 1)
    }
  end

  defmodule Untyped do
    use Grax

    schema do
      property foo: EX.foo()
      property bar: EX.bar(), type: []
    end
  end

  defmodule Types do
    use Grax

    schema do
      Grax.Schema.Type.builtins()
      |> Enum.each(fn {type, _} ->
        property type, apply(EX, type, []), type: type
      end)

      %{
        integers: [:integer],
        numerics: [:numeric]
      }
      |> Enum.each(fn {name, type} ->
        property name, apply(EX, name, []), type: type
      end)
    end
  end

  def types(subject \\ EX.S) do
    %Types{
      __id__: IRI.new(subject),
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
      negative_integer: -42,
      numeric: 42,
      date_time: ~U[2020-01-01 00:00:00Z],
      date: ~D[2020-01-01],
      time: ~T[00:00:00]
    }
  end

  defmodule DefaultValues do
    use Grax

    schema do
      property foo: EX.foo(), default: "foo"
      property bar: EX.bar(), type: :string, default: "bar"
      property baz: EX.baz(), type: :integer, default: 42
      link user: EX.user(), type: Example.User
      link posts: EX.post(), type: [Example.Post]
    end
  end

  defmodule SelfLinked do
    use Grax

    schema do
      property name: EX.name(), type: :string
      link next: EX.next(), type: Example.SelfLinked, depth: 1
    end
  end

  defmodule Circle do
    use Grax

    schema do
      property name: EX.name(), type: :string
      link link1: EX.link1(), type: [Example.Circle], depth: +1
      link link2: EX.link2(), type: [Example.Circle], depth: +1
    end
  end

  defmodule DepthPreloading do
    use Grax

    schema do
      link next: EX.next(), type: Example.DepthPreloading, depth: 2
    end
  end

  defmodule AddDepthPreloading do
    use Grax, depth: +3

    schema do
      link next: EX.next(), type: Example.AddDepthPreloading, depth: +2
    end
  end

  defmodule InverseProperties do
    use Grax

    schema do
      property name: EX.name()
      link foo: -EX.foo(), type: [Example.User]
    end
  end

  defmodule ClassDeclaration do
    use Grax

    schema EX.Class do
      property name: EX.name()
    end
  end

  defmodule Required do
    use Grax

    schema do
      property foo: EX.foo(), required: true
      property bar: EX.bar(), type: :integer, required: true
      property baz: EX.baz(), type: [], required: true
    end
  end

  defmodule IdsAsPropertyValues do
    use Grax

    schema do
      property foo: EX.foo()
      property foos: EX.foos(), type: []
      property iri: EX.iri(), type: :iri
      property iris: EX.iris(), type: [:iri]
    end
  end

  defmodule CustomMapping do
    use Grax

    @compile {:no_warn_undefined, Example.NS.EX}

    schema do
      property foo: EX.foo(), from_rdf: :to_foo, to_rdf: :from_foo
      property foos: EX.foos(), type: [], from_rdf: :to_foos, to_rdf: :from_foos
      property bar: EX.bar(), type: :string, from_rdf: :to_bar, to_rdf: :from_bar
      property bars: EX.bars(), type: [:string], from_rdf: :to_bars, to_rdf: :from_bars
    end

    def to_foo([object], description, graph) do
      assert %Description{} = description
      assert Description.include?(description, {EX.foo(), object})
      assert %Graph{} = graph
      assert Graph.include?(graph, {description.subject, EX.foo(), object})

      {:ok, {:foo, to_string(object)}}
    end

    def to_foo(_, _, _) do
      {:error, "multiple :foo values found"}
    end

    def from_foo({:foo, objects}, mapping) do
      assert %__MODULE__{} = mapping

      {:ok,
       objects
       |> List.wrap()
       |> Enum.map(&RDF.literal/1)}
    end

    def to_foos(objects, description, graph) do
      assert %Description{} = description
      assert Description.include?(description, {EX.foos(), objects})
      assert %Graph{} = graph
      assert Graph.include?(graph, {description.subject, EX.foos(), objects})

      {:ok, Enum.map(objects, &{:foo, to_string(&1)})}
    end

    def from_foos(objects, _mapping) do
      {:ok, Enum.map(objects, fn {:foo, object} -> RDF.literal(object) end)}
    end

    def to_bar([%IRI{} = iri], _, _) do
      {:ok, do_to_bar(iri)}
    end

    def from_bar(value, _mapping) do
      {:ok, apply(EX, String.to_atom(value), [])}
    end

    def to_bars(iris, _, _) do
      {:ok, Enum.map(iris, &do_to_bar/1)}
    end

    def from_bars([_], _mapping) do
      {:error, "not enough bars"}
    end

    def from_bars([value | rest], mapping) do
      {:ok, apply(EX, String.to_atom(value), []),
       {mapping.__id__, EX.other(), Enum.map(rest, &apply(EX, String.to_atom(&1), []))}}
    end

    defp do_to_bar(iri), do: IRI.parse(iri).path |> Path.basename()
  end
end
