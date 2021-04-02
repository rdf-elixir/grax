defmodule Example.IdSpecs do
  alias Example.{User, Post, Comment}
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

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

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

  defmodule GenericUuids do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      uuid schema: User, uuid_version: 4, uuid_format: :hex
      id_schema "posts/{uuid}", schema: Post, extensions: Grax.Id.UUID, uuid_version: 4
      uuid Comment, uuid_version: 1
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: User,
        extensions: [%Grax.Id.UUID{format: :hex, version: 4}]
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("posts/{uuid}"),
        schema: Post,
        extensions: [%Grax.Id.UUID{format: :default, version: 4}]
      }
    end

    def expected_id_schema(Comment) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Comment,
        extensions: [%Grax.Id.UUID{format: :default, version: 1}]
      }
    end
  end

  defmodule HashUuids do
    use Grax.Id.Spec
    import Grax.Id.UUID

    @custom_namespace UUID.uuid4()

    namespace "http://example.com/", prefix: :ex do
      uuid User, uuid_version: 5, uuid_namespace: :url, uuid_name: :canonical_email
      uuid Post, uuid_version: 3, uuid_namespace: @custom_namespace, uuid_name: :slug
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: User,
        extensions: [
          %Grax.Id.UUID{format: :default, version: 5, namespace: :url, name: :canonical_email}
        ]
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Post,
        extensions: [
          %Grax.Id.UUID{format: :default, version: 3, namespace: @custom_namespace, name: :slug}
        ]
      }
    end
  end

  defmodule ShortUuids do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      uuid5 User, namespace: :url, name: :canonical_email, format: :hex
      uuid4 Post
      uuid1 schema: Comment, format: :hex, template: "comments/{uuid}"
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: User,
        extensions: [
          %Grax.Id.UUID{
            format: :hex,
            version: 5,
            namespace: :url,
            name: :canonical_email
          }
        ]
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Post,
        extensions: [%Grax.Id.UUID{format: :default, version: 4}]
      }
    end

    def expected_id_schema(Comment) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("comments/{uuid}"),
        schema: Comment,
        extensions: [%Grax.Id.UUID{format: :hex, version: 1}]
      }
    end
  end

  defmodule Foo do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      uuid4 Example.WithIdSchema
    end

    def expected_id_schema() do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Example.WithIdSchema,
        extensions: [%Grax.Id.UUID{format: :default, version: 4}]
      }
    end
  end

  def expected_namespace(:ex) do
    %Id.Namespace{
      segment: "http://example.com/",
      prefix: :ex,
      base: false
    }
  end

  def compiled_template(template) do
    {:ok, template} = YuriTemplate.parse(template)
    template
  end
end
