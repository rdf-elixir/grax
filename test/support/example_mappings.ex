defmodule Example do
  alias Example.NS.EX
  alias RDF.IRI

  @compile {:no_warn_undefined, Example.NS.EX}

  defmodule User do
    use RDF.Mapping

    schema EX.User do
      property :name, EX.name(), type: :string
      property :age, EX.age(), type: :integer
      property :email, EX.email(), type: [:string]
      property :password, nil

      link :posts, EX.post(), type: [Example.Post]
      link :comments, EX.comment(), type: [Example.Comment]
    end
  end

  defmodule Post do
    use RDF.Mapping

    schema EX.Post do
      property :title, EX.title(), type: :string
      property :content, EX.content(), type: :string
      link :author, EX.author(), type: Example.User
      link :comments, EX.comment(), type: [Example.Comment]
    end
  end

  defmodule Comment do
    use RDF.Mapping

    schema EX.Comment do
      property :content, EX.content(), type: :string
      link :about, EX.about(), type: Example.Post
      link :author, EX.author(), type: Example.User
    end
  end

  def user(id, opts \\ [depth: 1])

  def user(EX.User0, depth: 0) do
    %Example.User{
      __iri__: IRI.to_string(EX.User0),
      name: "John Doe",
      age: 42,
      email: ~w[jd@example.com john@doe.com]
    }
  end

  def user(EX.User1, depth: 0) do
    %Example.User{
      __iri__: IRI.to_string(EX.User1),
      name: "Erika Mustermann",
      email: ["erika@mustermann.de"]
    }
  end

  def user(EX.User2, depth: 0) do
    %Example.User{
      __iri__: IRI.to_string(EX.User2),
      name: "Max Mustermann",
      email: ["max@mustermann.de"]
    }
  end

  def user(EX.User0, depth: depth) do
    %Example.User{user(EX.User0, depth: 0) | posts: [post(depth: depth - 1)], comments: []}
  end

  def post(depth: 0) do
    %Example.Post{
      __iri__: IRI.to_string(EX.Post0),
      title: "Lorem ipsum",
      content: "Lorem ipsum dolor sit amet, …"
    }
  end

  def post(depth: depth) do
    %Example.Post{post(depth: 0) | comments: comments(depth: depth - 1)}
    #    %Example.Post{post(depth: 0) | comments: comments(depth: 0), author: user(depth: 0)}
  end

  def comments(depth: depth) do
    [comment(EX.Comment1, depth: depth), comment(EX.Comment2, depth: depth)]
  end

  def comment(EX.Comment1, depth: 0) do
    %Example.Comment{
      __iri__: IRI.to_string(EX.Comment1),
      content: "First"
    }
  end

  def comment(EX.Comment2, depth: 0) do
    %Example.Comment{
      __iri__: IRI.to_string(EX.Comment2),
      content: "Second"
    }
  end

  def comment(EX.Comment1, depth: depth) do
    %Example.Comment{
      comment(EX.Comment1, depth: 0)
      | author: user(EX.User1, depth: depth - 1)
        #        about: post(depth: depth - 1)
    }
  end

  def comment(EX.Comment2, depth: depth) do
    %Example.Comment{
      comment(EX.Comment2, depth: 0)
      | author: user(EX.User2, depth: depth - 1)
        #        about: post(depth: depth - 1)
    }
  end

  defmodule Untyped do
    use RDF.Mapping

    schema do
      property :foo, EX.foo()
      property :bar, EX.bar(), type: []
    end
  end

  defmodule Types do
    use RDF.Mapping

    schema do
      RDF.Mapping.Schema.Type.builtins()
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
      __iri__: IRI.to_string(subject),
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
    }
  end

  defmodule DefaultValues do
    use RDF.Mapping

    schema do
      property :foo, EX.foo(), default: "foo"
      property :bar, EX.bar(), type: :string, default: "bar"
      property :baz, EX.baz(), type: :integer, default: 42
      link :user, EX.user(), type: Example.User
      link :posts, EX.post(), type: [Example.Post]
    end
  end

  defmodule SelfLinked do
    use RDF.Mapping

    schema do
      property :name, EX.name(), type: :string
      link :next, EX.next(), type: Example.SelfLinked, preload: true
    end
  end

  defmodule Circle do
    use RDF.Mapping

    schema do
      property :name, EX.name(), type: :string
      link :link1, EX.link1(), type: [Example.Circle], preload: +1
      link :link2, EX.link2(), type: [Example.Circle], preload: +1
    end
  end

  defmodule DepthPreloading do
    use RDF.Mapping

    schema do
      link :next, EX.next(), type: Example.DepthPreloading, preload: 2
    end
  end

  defmodule AddDepthPreloading do
    use RDF.Mapping, preload: +3

    schema do
      link :next, EX.next(), type: Example.AddDepthPreloading, preload: +2
    end
  end

  defmodule InverseProperties do
    use RDF.Mapping

    schema do
      property :name, EX.name()
      link :foo, -EX.foo(), type: [Example.User]
    end
  end

  defmodule ClassDeclaration do
    use RDF.Mapping

    schema EX.Class do
      property :name, EX.name()
    end
  end
end
