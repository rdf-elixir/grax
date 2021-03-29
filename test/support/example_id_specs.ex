defmodule Example.IdSpecs do
  alias Example.{User, Post}
  alias Grax.Id

  defmodule FlatNs do
    use Grax.Id.Spec

    namespace "http://example.com/", prefix: :ex do
    end
  end

  defmodule FlatNsWithVocabTerms do
    use Grax.Id.Spec

    alias Example.NS.EX

    namespace EX, prefix: :ex do
    end
  end

  defmodule FlatBase do
    use Grax.Id.Spec

    alias Example.NS.EX

    base EX do
    end
  end

  defmodule NestedNs do
    use Grax.Id.Spec

    namespace "http://example.com/", prefix: :ex do
      namespace "foo/", prefix: :foo do
        namespace "bar/", prefix: :bar
        namespace "baz/", prefix: :baz
      end

      namespace "qux/", prefix: :qux
    end
  end

  defmodule GenericIds do
    use Grax.Id.Spec

    namespace "http://example.com/", prefix: :ex do
      id_schema "users/{name}", schema: User
      id Post, "posts/{slug}"
    end

    def expected_namespace(:ex) do
      %Id.Namespace{
        segment: "http://example.com/",
        prefix: :ex,
        base: false
      }
    end

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("users/{name}"),
        schema: User
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("posts/{slug}"),
        schema: Post
      }
    end
  end

  def compiled_template(template) do
    {:ok, template} = YuriTemplate.parse(template)
    template
  end
end
