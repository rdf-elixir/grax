defmodule Example do
  alias Example.NS.EX

  defmodule User do
    use RDF.Mapping

    schema do
      property :name, EX.name(), type: :string
      property :age, EX.age(), type: :integer
      property :email, EX.email(), type: [:string]
      property :password, nil

      has_many :posts, EX.posts(), type: Example.Post
    end
  end

  defmodule Post do
    use RDF.Mapping

    schema do
      property :title, EX.title(), type: :string
      property :content, EX.content(), type: :string
      has_one :author, EX.author(), type: Example.User
    end
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

  defmodule DefaultValues do
    use RDF.Mapping

    schema do
      property :foo, EX.foo(), default: "foo"
      property :bar, EX.bar(), type: :string, default: "bar"
      property :baz, EX.baz(), type: :integer, default: 42
      has_one :user, EX.user(), type: Example.User
      has_many :posts, EX.post(), type: Example.Post
    end
  end
end
