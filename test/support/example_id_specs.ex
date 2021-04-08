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
      id Example.WithIdSchemaNested, "bar/{bar}"
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

  defmodule VarProc do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      id Example.VarProcA, "foo/{gen}", var_proc: :upcase_name
      uuid5 Example.VarProcB, namespace: :oid, name: :gen, var_proc: :upcase_name
    end

    def upcase_name(%{name: name} = vars) do
      {:ok, Map.put(vars, :gen, String.upcase(name))}
    end

    def upcase_name(vars), do: {:ok, vars}

    def expected_id_schema(Example.VarProcA) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("foo/{gen}"),
        schema: Example.VarProcA,
        var_proc: {__MODULE__, :upcase_name}
      }
    end

    def expected_id_schema(Example.VarProcB) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Example.VarProcB,
        var_proc: {__MODULE__, :upcase_name},
        extensions: [
          %Grax.Id.UUID{format: :default, version: 5, namespace: :oid, name: :gen}
        ]
      }
    end
  end

  defmodule SeparateCustomSelector do
    def uuid4?(Example.WithCustomSelectedIdSchemaB, %{bar: "bar"}), do: true
    def uuid4?(_, _), do: false

    def uuid5?(Example.WithCustomSelectedIdSchemaB, %{bar: content}) when content != "", do: true
    def uuid5?(_, _), do: false
  end

  defmodule CustomSelector do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      id_schema "foo/{foo}", selector: :test_selector

      uuid selector: {SeparateCustomSelector, :uuid5?},
           uuid_version: 5,
           uuid_name: :bar,
           uuid_namespace: :url

      uuid selector: {SeparateCustomSelector, :uuid4?}, uuid_version: 4
    end

    def test_selector(Example.WithCustomSelectedIdSchemaA, _), do: true
    def test_selector(_, _), do: false

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(:foo) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("foo/{foo}"),
        schema: nil,
        selector: {__MODULE__, :test_selector},
        extensions: nil
      }
    end

    def expected_id_schema(:uuid5) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: nil,
        selector: {Example.IdSpecs.SeparateCustomSelector, :uuid5?},
        extensions: [
          %Grax.Id.UUID{format: :default, version: 5, name: :bar, namespace: :url}
        ]
      }
    end

    def expected_id_schema(:uuid4) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: nil,
        selector: {Example.IdSpecs.SeparateCustomSelector, :uuid4?},
        extensions: [%Grax.Id.UUID{format: :default, version: 4}]
      }
    end
  end

  defmodule AppConfigIdSpec do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      uuid4 Grax.ConfigTest.TestSchema
    end

    def expected_id_schema() do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Grax.ConfigTest.TestSchema,
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