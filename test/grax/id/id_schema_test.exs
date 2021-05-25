defmodule Grax.Id.SchemaTest do
  use Grax.TestCase

  import RDF.Sigils

  alias Grax.Id
  alias Example.{IdSpecs, User, Post}

  describe "generate_id/2" do
    test "based on another field" do
      assert IdSpecs.GenericIds.expected_id_schema(Post)
             |> Id.Schema.generate_id(Example.post()) ==
               {:ok, ~I<http://example.com/posts/lorem-ipsum>}

      keyword_list = Example.post() |> Map.from_struct() |> Keyword.new()

      assert IdSpecs.GenericIds.expected_id_schema(Post)
             |> Id.Schema.generate_id(keyword_list) ==
               {:ok, ~I<http://example.com/posts/lorem-ipsum>}

      assert IdSpecs.GenericIds.expected_id_schema(User)
             |> Id.Schema.generate_id(Example.user(EX.User0)) ==
               {:ok, ~I<http://example.com/users/John%20Doe>}
    end

    test "with var_mapping" do
      assert IdSpecs.VarMapping.expected_id_schema(Example.VarMappingA)
             |> Map.put(:schema, Example.VarMappingA)
             |> Id.Schema.generate_id(%{name: "foo"}) ==
               {:ok, ~I<http://example.com/foo/FOO>}

      assert IdSpecs.VarMapping.expected_id_schema(Example.VarMappingC)
             |> Id.Schema.generate_id(%{name: "foo"}) ==
               {:ok, ~I<http://example.com/feab40e1fca77c7360ccca1481bb8ba5f919ce3a>}
    end

    test "non-string values are converted to strings" do
      assert IdSpecs.Foo.expected_id_schema(Example.WithIdSchemaNested)
             |> Id.Schema.generate_id(bar: 42) ==
               {:ok, ~I<http://example.com/bar/42>}
    end

    test "when no values for the template parameters present" do
      assert IdSpecs.GenericIds.expected_id_schema(User)
             |> Id.Schema.generate_id(%{}) ==
               {:error, "no value for id schema template parameter: name"}

      assert IdSpecs.GenericIds.expected_id_schema(User)
             |> Id.Schema.generate_id(%{name: nil}) ==
               {:error, "no value for id schema template parameter: name"}
    end

    # generation of UUID-based ids are tested in uuid_test.exs
  end
end
