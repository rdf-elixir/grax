defmodule Example do
  alias Example.NS.EX
  alias RDF.{IRI, Description, Graph}
  alias Grax.RDF.Loader

  import ExUnit.Assertions

  @compile {:no_warn_undefined, Example.NS.EX}

  defmodule User do
    use Grax.Schema

    @compile {:no_warn_undefined, Example.NS.EX}

    schema EX.User do
      property name: EX.name(), type: :string
      property email: EX.email(), type: list_of(:string)
      property age: EX.age(), type: :integer

      field :password
      field :canonical_email, from_rdf: :canonical_email

      property customer_type: RDF.type(),
               from_rdf: :customer_type_from_rdf,
               to_rdf: :customer_type_to_rdf

      link posts: EX.post(), type: list_of(Example.Post)
      link comments: -EX.author(), type: list_of(%{EX.Comment => Example.Comment})

      def customer_type_from_rdf(types, _description, _graph) do
        {:ok, if(RDF.iri(EX.PremiumUser) in types, do: :premium_user)}
      end

      def customer_type_to_rdf(:premium_user, _user), do: {:ok, EX.PremiumUser}
      def customer_type_to_rdf(_, _), do: {:ok, nil}
    end

    def canonical_email(description, _) do
      {:ok,
       case description[EX.email()] do
         [email | _] -> "mailto:#{to_string(email)}"
         _ -> nil
       end}
    end
  end

  defmodule Post do
    use Grax.Schema

    @compile {:no_warn_undefined, Example.NS.EX}

    schema EX.Post do
      property title: EX.title(), type: :string
      property content: EX.content(), type: :string
      link author: EX.author(), type: Example.User
      link comments: EX.comment(), type: list_of(Example.Comment)

      field :slug, from_rdf: :slug
    end

    def slug(description, _) do
      {:ok,
       case description[EX.title()] do
         [title | _] ->
           title
           |> to_string()
           |> String.downcase()
           |> String.replace(" ", "-")

         _ ->
           nil
       end}
    end
  end

  defmodule Comment do
    use Grax.Schema

    schema EX.Comment do
      property content: EX.content(), type: :string
      link about: EX.about(), type: Example.Post
      link author: EX.author(), type: Example.User
    end
  end

  def user(id, opts \\ [depth: 0])

  def user(EX.User0, depth: 0) do
    %Example.User{
      __id__: IRI.new(EX.User0),
      name: "John Doe",
      age: 42,
      email: ~w[jd@example.com john@doe.com],
      customer_type: :premium_user,
      canonical_email: "mailto:jd@example.com"
    }
    |> Loader.init_link_properties()
  end

  def user(EX.User1, depth: 0) do
    %Example.User{
      __id__: IRI.new(EX.User1),
      name: "Erika Mustermann",
      email: ["erika@mustermann.de"],
      canonical_email: "mailto:erika@mustermann.de"
    }
    |> Loader.init_link_properties()
  end

  def user(EX.User2, depth: 0) do
    %Example.User{
      __id__: IRI.new(EX.User2),
      name: "Max Mustermann",
      email: ["max@mustermann.de"],
      canonical_email: "mailto:max@mustermann.de"
    }
    |> Loader.init_link_properties()
  end

  def user(EX.User0, depth: depth) do
    %Example.User{user(EX.User0, depth: 0) | posts: [post(depth: depth - 1)], comments: []}
  end

  def post(opts \\ [depth: 1])

  def post(depth: 0) do
    %Example.Post{
      __id__: IRI.new(EX.Post0),
      title: "Lorem ipsum",
      content: "Lorem ipsum dolor sit amet, …",
      slug: "lorem-ipsum"
    }
    |> Loader.init_link_properties()
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
    |> Loader.init_link_properties()
  end

  def comment(EX.Comment2, depth: 0) do
    %Example.Comment{
      __id__: IRI.new(EX.Comment2),
      content: "Second"
    }
    |> Loader.init_link_properties()
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

  defmodule WithIdSchema do
    use Grax.Schema, id_spec: Example.IdSpecs.Foo

    schema do
      property foo: EX.foo()
    end
  end

  defmodule WithIdSchemaNested do
    use Grax.Schema, id_spec: Example.IdSpecs.Foo

    schema do
      property bar: EX.bar()
      link foo: EX.foo(), type: Example.WithIdSchema
      link more: EX.more(), type: list_of(__MODULE__)
    end
  end

  defmodule VarProcA do
    use Grax.Schema, id_spec: Example.IdSpecs.VarProc

    schema do
      property name: EX.name()
    end
  end

  defmodule VarProcB do
    use Grax.Schema, id_spec: Example.IdSpecs.VarProc

    schema do
      property name: EX.name()
    end
  end

  defmodule VarProcC do
    use Grax.Schema, id_spec: Example.IdSpecs.VarProc

    schema do
      property name: EX.name()
    end
  end

  defmodule WithCustomSelectedIdSchemaA do
    use Grax.Schema, id_spec: Example.IdSpecs.CustomSelector

    schema do
      property foo: EX.foo()
    end
  end

  defmodule WithCustomSelectedIdSchemaB do
    use Grax.Schema, id_spec: Example.IdSpecs.CustomSelector

    schema do
      property bar: EX.bar()
    end
  end

  defmodule Untyped do
    use Grax.Schema

    schema do
      property foo: EX.foo()
      property bar: EX.bar(), type: list()
    end
  end

  defmodule Datatypes do
    use Grax.Schema

    schema do
      Grax.Datatype.builtins()
      |> Enum.each(fn {type, _} ->
        property type, apply(EX, type, []), type: type
      end)

      %{
        integers: :integer,
        numerics: :numeric
      }
      |> Enum.each(fn {name, type} ->
        property name, apply(EX, name, []), type: list_of(type)
      end)
    end
  end

  def types(subject \\ EX.S) do
    %Datatypes{
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
    use Grax.Schema

    schema do
      property foo: EX.foo(), default: "foo"
      property bar: EX.bar(), type: :string, default: "bar"
      property baz: EX.baz(), type: :integer, default: 42
      link user: EX.user(), type: Example.User
      link posts: EX.post(), type: list_of(Example.Post)
    end
  end

  defmodule SelfLinked do
    use Grax.Schema

    schema do
      property name: EX.name(), type: :string
      link next: EX.next(), type: Example.SelfLinked, depth: 1
    end
  end

  defmodule Circle do
    use Grax.Schema

    schema do
      property name: EX.name(), type: :string
      link link1: EX.link1(), type: list_of(Example.Circle), depth: +1
      link link2: EX.link2(), type: list_of(Example.Circle), depth: +1
    end
  end

  defmodule DepthPreloading do
    use Grax.Schema

    schema do
      link next: EX.next(), type: Example.DepthPreloading, depth: 2
    end
  end

  defmodule AddDepthPreloading do
    use Grax.Schema, depth: +3

    schema do
      link next: EX.next(), type: Example.AddDepthPreloading, depth: +2
    end
  end

  defmodule InverseProperties do
    use Grax.Schema

    schema do
      property name: EX.name()
      link foo: -EX.foo(), type: list_of(Example.User)
    end
  end

  defmodule HeterogeneousLinks do
    use Grax.Schema

    schema do
      property name: EX.name()

      link one: EX.one(),
           type: %{
             EX.Post => Example.Post,
             EX.Comment => Example.Comment
           }

      link strict_one: EX.strictOne(),
           type: %{
             EX.Post => Example.Post,
             EX.Comment => Example.Comment
           },
           on_type_mismatch: :error

      link many: EX.many(),
           type:
             list_of(%{
               nil => Example.Post,
               EX.Comment => Example.Comment
             })
    end
  end

  defmodule ClassDeclaration do
    use Grax.Schema

    schema EX.Class do
      property name: EX.name()
    end
  end

  defmodule Required do
    use Grax.Schema

    schema do
      property foo: EX.foo(), required: true
      property bar: EX.bar(), type: :integer, required: true
      property baz: EX.baz(), type: list(), required: true

      link l1: EX.lp1(), type: Example.User, required: true
      link l2: EX.lp2(), type: list_of(Example.User), required: true
    end
  end

  defmodule Cardinalities do
    use Grax.Schema

    schema do
      property p1: EX.p1(), type: list(card: 2)
      property p2: EX.p2(), type: list_of(:integer, card: 2..4)
      property p3: EX.p3(), type: list(min: 3)

      link l1: EX.lp1(), type: list_of(Example.User, card: 2..3)
      link l2: EX.lp2(), type: list_of(Example.User, min: 2)
    end
  end

  defmodule IdsAsPropertyValues do
    use Grax.Schema

    schema do
      property foo: EX.foo()
      property foos: EX.foos(), type: list()
      property iri: EX.iri(), type: :iri
      property iris: EX.iris(), type: list_of(:iri)
    end
  end

  defmodule ParentSchema do
    use Grax.Schema

    schema do
      property dp1: EX.dp1(), from_rdf: :upcase
      property dp2: EX.dp2()

      field :f1, default: :foo
      field :f2

      link lp1: EX.lp1(), type: Example.User
      link lp2: EX.lp2(), type: Example.User
    end

    def upcase([foo], _, _), do: {:ok, foo |> to_string |> String.upcase()}
  end

  defmodule ChildSchema do
    use Grax.Schema

    schema inherit: Example.ParentSchema do
      property dp2: EX.dp22()
      property dp3: EX.dp3()

      field :f2, from_rdf: :foo
      field :f3

      link lp2: EX.lp22(), type: Example.User
      link lp3: EX.lp3(), type: Example.User
    end

    def foo(_, _), do: {:ok, :foo}
  end

  defmodule ChildSchemaWithClass do
    use Grax.Schema

    schema EX.Class < Example.ParentSchema do
    end
  end

  defmodule AnotherParentSchema do
    use Grax.Schema

    schema do
      property dp1: EX.dp1(), from_rdf: {Example.ParentSchema, :upcase}
      property dp2: EX.dp22()
      property dp3: EX.dp3()

      field :f1
      field :f2
      field :f3

      link lp1: EX.lp1(), type: Example.User
      link lp3: EX.lp3(), type: Example.User
    end
  end

  defmodule ChildOfMany do
    use Grax.Schema

    schema EX.Class < [Example.ParentSchema, Example.AnotherParentSchema] do
      property dp2: EX.dp23()
      property dp4: EX.dp4()

      field :f1
      field :f4

      link lp4: EX.lp4(), type: Example.User
    end

    def foo(_, _), do: {:ok, :foo}
  end

  defmodule CustomMapping do
    use Grax.Schema

    @compile {:no_warn_undefined, Example.NS.EX}

    schema do
      property foo: EX.foo(), from_rdf: :to_foo, to_rdf: :from_foo
      property foos: EX.foos(), type: list(), from_rdf: :to_foos, to_rdf: :from_foos
      property bar: EX.bar(), type: :string, from_rdf: :to_bar, to_rdf: :from_bar
      property bars: EX.bars(), type: list_of(:string), from_rdf: :to_bars, to_rdf: :from_bars
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

  defmodule CustomMappingOnCustomFields do
    use Grax.Schema

    schema do
      field :uuid, from_rdf: :to_uuid
    end

    def to_uuid(%Description{subject: %{value: "urn:uuid:" <> uuid}}, graph) do
      assert %Graph{} = graph

      {:ok, uuid}
    end

    def to_uuid(_, _), do: {:error, "invalid id"}
  end

  defmodule CustomMappingInSeparateModule do
    use Grax.Schema

    schema do
      property foo: EX.foo(),
               from_rdf: {Example.SeparateCustomMappingModule, :to_foo},
               to_rdf: {Example.SeparateCustomMappingModule, :from_foo}

      field :bar, from_rdf: {Example.SeparateCustomMappingModule, :to_bar}
    end
  end

  defmodule SeparateCustomMappingModule do
    def to_foo([foo], _, _), do: {:ok, foo |> to_string |> String.upcase()}
    def from_foo(foo, _), do: {:ok, foo |> String.downcase()}

    def to_bar(_, _), do: {:ok, "bar"}
  end
end
