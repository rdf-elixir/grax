# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc
defmodule Example.IdSpecs do
  alias Example.{User, Post, Comment}
  alias Grax.Id

  import ExUnit.Assertions

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

  defmodule NestedBase do
    use Grax.Id.Spec

    alias Example.NS.EX

    namespace EX do
      base "foo/" do
      end
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

  defmodule NsWithExpressions do
    use Grax.Id.Spec

    @domain "http://example.com/"
    def domain, do: @domain

    @path "sub/"

    namespace @domain do
      base @path do
      end
    end
  end

  defmodule NsWithExpressions2 do
    use Grax.Id.Spec

    namespace NsWithExpressions.domain(), prefix: :ex do
    end
  end

  defmodule UrnNs do
    use Grax.Id.Spec

    urn :isbn do
    end

    urn :uuid do
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

  defmodule GenericShortIds do
    use Grax.Id.Spec

    namespace "http://example.com/", prefix: :ex do
      id User.name()
      id Post.slug()
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{name}"),
        schema: User
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{slug}"),
        schema: Post
      }
    end
  end

  defmodule MultipleSchemas do
    use Grax.Id.Spec
    import Grax.Id.Hash

    namespace "http://example.com/", prefix: :ex do
      id [Example.MultipleSchemasA, Example.MultipleSchemasB], "{foo}"
      hash [Post, Comment], data: :content, algorithm: :md5
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(:foo) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{foo}"),
        schema: [Example.MultipleSchemasA, Example.MultipleSchemasB]
      }
    end

    def expected_id_schema(:content) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{hash}"),
        schema: [Post, Comment],
        extensions: [
          %Grax.Id.Hash{algorithm: :md5, data_variable: :content}
        ]
      }
    end
  end

  defmodule UrnIds do
    use Grax.Id.Spec

    urn :example do
      id User, "{name}"
      id Post.slug()
    end

    urn :other do
      id Example.Datatypes.integer()
    end

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{nid: :example, string: "urn:example:"},
        template: Example.IdSpecs.compiled_template("{name}"),
        schema: User
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{nid: :example, string: "urn:example:"},
        template: Example.IdSpecs.compiled_template("{slug}"),
        schema: Post
      }
    end

    def expected_id_schema(:integer) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{nid: :other, string: "urn:other:"},
        template: Example.IdSpecs.compiled_template("{integer}"),
        schema: Example.Datatypes
      }
    end
  end

  defmodule GenericUuids do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      uuid schema: User, version: 4, format: :hex
      id_schema "posts/{uuid}", schema: Post, extensions: Grax.Id.UUID, uuid_version: 4
      uuid Comment, version: 1
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
      uuid User, version: 5, namespace: :url, name_var: :canonical_email
      uuid Post, version: 3, namespace: @custom_namespace, name_var: :slug
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: User,
        extensions: [
          %Grax.Id.UUID{format: :default, version: 5, namespace: :url, name_var: :canonical_email}
        ]
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Post,
        extensions: [
          %Grax.Id.UUID{
            format: :default,
            version: 3,
            namespace: @custom_namespace,
            name_var: :slug
          }
        ]
      }
    end
  end

  defmodule ShortUuids do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      uuid5 User, namespace: :url, name_var: :canonical_email, format: :hex
      uuid4 Post
      uuid1 schema: Comment, format: :hex, template: "comments/{uuid}"
      uuid5 Example.SelfLinked.name(), namespace: :url
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
            name_var: :canonical_email
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

    def expected_id_schema(Example.SelfLinked) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Example.SelfLinked,
        extensions: [
          %Grax.Id.UUID{
            format: :default,
            version: 5,
            namespace: :url,
            name_var: :name
          }
        ]
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

    def expected_id_schema(Example.WithIdSchema) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Example.WithIdSchema,
        extensions: [%Grax.Id.UUID{format: :default, version: 4}]
      }
    end

    def expected_id_schema(Example.WithIdSchemaNested) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("bar/{bar}"),
        schema: Example.WithIdSchemaNested
      }
    end
  end

  defmodule Hashing do
    use Grax.Id.Spec
    import Grax.Id.Hash

    namespace "http://example.com/", prefix: :ex do
      hash User, data: :canonical_email, algorithm: :sha512
      hash Post, data: :content, algorithm: :sha256
      hash Comment.content(), algorithm: :md5
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{hash}"),
        schema: User,
        extensions: [
          %Grax.Id.Hash{algorithm: :sha512, data_variable: :canonical_email}
        ]
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{hash}"),
        schema: Post,
        extensions: [
          %Grax.Id.Hash{algorithm: :sha256, data_variable: :content}
        ]
      }
    end

    def expected_id_schema(Comment) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{hash}"),
        schema: Comment,
        extensions: [
          %Grax.Id.Hash{algorithm: :md5, data_variable: :content}
        ]
      }
    end
  end

  defmodule UuidUrns do
    use Grax.Id.Spec
    import Grax.Id.UUID

    urn :uuid do
      uuid4 User
      uuid5 Post.content(), namespace: :url
    end

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{nid: :uuid, string: "urn:uuid:"},
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: User,
        extensions: [%Grax.Id.UUID{format: :urn, version: 4}]
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{nid: :uuid, string: "urn:uuid:"},
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Post,
        extensions: [
          %Grax.Id.UUID{
            format: :urn,
            version: 5,
            namespace: :url,
            name_var: :content
          }
        ]
      }
    end
  end

  defmodule HashUrns do
    use Grax.Id.Spec
    import Grax.Id.Hash

    urn :sha1 do
      hash Post.content(), algorithm: :sha
    end

    urn :hash do
      hash Comment.content(), template: ":sha256:{hash}", algorithm: :sha256
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{nid: :sha1, string: "urn:sha1:"},
        template: Example.IdSpecs.compiled_template("{hash}"),
        schema: Post,
        extensions: [
          %Grax.Id.Hash{algorithm: :sha, data_variable: :content}
        ]
      }
    end

    def expected_id_schema(Comment) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{nid: :hash, string: "urn:hash:"},
        template: Example.IdSpecs.compiled_template(":sha256:{hash}"),
        schema: Comment,
        extensions: [
          %Grax.Id.Hash{algorithm: :sha256, data_variable: :content}
        ]
      }
    end
  end

  defmodule BlankNodes do
    use Grax.Id.Spec

    blank_node User

    namespace "http://example.com/", prefix: :ex do
      id Example.SelfLinked.name()
      blank_node [Post, Comment, Example.WithBlankNodeIdSchema]
      id Example.Datatypes.string()
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_id_schema(User), do: Grax.Id.Schema.new_blank_node_schema(nil, User)

    def expected_id_schema(Example.WithBlankNodeIdSchema) do
      Grax.Id.Schema.new_blank_node_schema(
        expected_namespace(:ex),
        [Post, Comment, Example.WithBlankNodeIdSchema]
      )
    end

    def expected_id_schema(Example.SelfLinked) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{name}"),
        schema: Example.SelfLinked
      }
    end

    def expected_id_schema(Example.Datatypes) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{string}"),
        schema: Example.Datatypes
      }
    end
  end

  defmodule WithCounter do
    use Grax.Id.Spec

    alias Grax.Id.Counter

    namespace "http://example.com/", prefix: :ex do
      id_schema "users/{counter}", schema: User, counter: :user
      id Post, "posts/{counter}", counter: :post, counter_adapter: Grax.Id.Counter.TextFile

      namespace "comments/", counter_adapter: Grax.Id.Counter.TextFile do
        id Comment.counter(), counter: :comment
      end
    end

    def expected_namespace(:ex), do: Example.IdSpecs.expected_namespace(:ex)

    def expected_namespace(:comments) do
      %Id.Namespace{
        parent: expected_namespace(:ex),
        uri: "http://example.com/comments/",
        options: [counter_adapter: Grax.Id.Counter.TextFile]
      }
    end

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("users/{counter}"),
        schema: User,
        counter: {Counter.Dets, :user}
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("posts/{counter}"),
        schema: Post,
        counter: {Counter.TextFile, :post}
      }
    end

    def expected_id_schema(Comment) do
      %Id.Schema{
        namespace: expected_namespace(:comments),
        template: Example.IdSpecs.compiled_template("{counter}"),
        schema: Comment,
        counter: {Counter.TextFile, :comment}
      }
    end
  end

  defmodule VarMapping do
    use Grax.Id.Spec
    import Grax.Id.{UUID, Hash}

    namespace "http://example.com/", prefix: :ex do
      id [Example.VarMappingA, Example.VarMappingD], "foo/{gen}", var_mapping: :upcase_name
      uuid5 Example.VarMappingB, namespace: :oid, name_var: :gen, var_mapping: :upcase_name
      hash Example.VarMappingC, data: :gen, algorithm: :sha, var_mapping: :upcase_name
    end

    def upcase_name(%{name: name} = vars) do
      assert vars.__schema__
      assert is_atom(vars.__schema__)
      {:ok, Map.put(vars, :gen, String.upcase(name))}
    end

    def upcase_name(vars), do: {:ok, vars}

    def expected_id_schema(Example.VarMappingA) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("foo/{gen}"),
        schema: [Example.VarMappingA, Example.VarMappingD],
        var_mapping: {__MODULE__, :upcase_name}
      }
    end

    def expected_id_schema(Example.VarMappingB) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Example.VarMappingB,
        var_mapping: {__MODULE__, :upcase_name},
        extensions: [
          %Grax.Id.UUID{format: :default, version: 5, namespace: :oid, name_var: :gen}
        ]
      }
    end

    def expected_id_schema(Example.VarMappingC) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{hash}"),
        schema: Example.VarMappingC,
        var_mapping: {__MODULE__, :upcase_name},
        extensions: [
          %Grax.Id.Hash{algorithm: :sha, data_variable: :gen}
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
           uuid_name_var: :bar,
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
          %Grax.Id.UUID{format: :default, version: 5, name_var: :bar, namespace: :url}
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

  defmodule OptionInheritance do
    use Grax.Id.Spec, uuid_format: :hex

    import Grax.Id.{UUID, Hash}

    namespace "http://example.com/",
      prefix: :ex,
      hash_algorithm: :sha,
      uuid_version: 3,
      uuid_namespace: :url do
      namespace "foo/", uuid_version: 5, uuid_namespace: :oid, uuid_format: :default do
        uuid User.canonical_email()
        hash Post.content()
      end

      uuid Comment.content()
      uuid5 Example.SelfLinked.name()
    end

    urn :uuid, uuid_version: 5, uuid_namespace: :oid do
      uuid Example.Datatypes.integer()
    end

    def expected_namespace(:ex) do
      %{
        Example.IdSpecs.expected_namespace(:ex)
        | options: [
            uuid_format: :hex,
            hash_algorithm: :sha,
            uuid_version: 3,
            uuid_namespace: :url
          ]
      }
    end

    def expected_namespace(:foo) do
      %Id.Namespace{
        parent: expected_namespace(:ex),
        uri: "http://example.com/foo/",
        options: [uuid_version: 5, uuid_namespace: :oid, uuid_format: :default]
      }
    end

    def expected_id_schema(User) do
      %Id.Schema{
        namespace: expected_namespace(:foo),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: User,
        extensions: [
          %Grax.Id.UUID{format: :default, version: 5, namespace: :oid, name_var: :canonical_email}
        ]
      }
    end

    def expected_id_schema(Post) do
      %Id.Schema{
        namespace: expected_namespace(:foo),
        template: Example.IdSpecs.compiled_template("{hash}"),
        schema: Post,
        extensions: [%Grax.Id.Hash{algorithm: :sha, data_variable: :content}]
      }
    end

    def expected_id_schema(Comment) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Comment,
        extensions: [
          %Grax.Id.UUID{format: :hex, version: 3, namespace: :url, name_var: :content}
        ]
      }
    end

    def expected_id_schema(Example.SelfLinked) do
      %Id.Schema{
        namespace: expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Example.SelfLinked,
        extensions: [
          %Grax.Id.UUID{format: :hex, version: 5, namespace: :url, name_var: :name}
        ]
      }
    end

    def expected_id_schema(Example.Datatypes) do
      %Id.Schema{
        namespace: %Id.UrnNamespace{
          nid: :uuid,
          string: "urn:uuid:",
          options: [uuid_version: 5, uuid_namespace: :oid]
        },
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: Example.Datatypes,
        extensions: [
          %Grax.Id.UUID{format: :urn, version: 5, namespace: :oid, name_var: :integer}
        ]
      }
    end
  end

  defmodule AppConfigIdSpec do
    use Grax.Id.Spec
    import Grax.Id.UUID

    namespace "http://example.com/", prefix: :ex do
      uuid4 Grax.ConfigTest.TestSchema1
      uuid4 Grax.ConfigTest.TestSchema2
    end

    def expected_id_schema(schema) do
      %Id.Schema{
        namespace: Example.IdSpecs.expected_namespace(:ex),
        template: Example.IdSpecs.compiled_template("{uuid}"),
        schema: schema,
        extensions: [%Grax.Id.UUID{format: :default, version: 4}]
      }
    end
  end

  def expected_namespace(:ex) do
    %Id.Namespace{
      uri: "http://example.com/",
      prefix: :ex
    }
  end

  def compiled_template(template) do
    {:ok, template} = YuriTemplate.parse(template)
    template
  end
end
