defmodule Grax.Id.SchemaTest do
  use Grax.TestCase

  import RDF.Sigils

  alias Grax.Id
  alias Example.{IdSpecs, User, Post}

  describe "generate_id/2" do
    test "based on another field" do
      assert Id.Schema.generate_id(IdSpecs.GenericIds.expected_id_schema(Post), Example.post()) ==
               {:ok, ~I<http://example.com/posts/lorem-ipsum>}

      keyword_list = Example.post() |> Map.from_struct() |> Keyword.new()

      assert Id.Schema.generate_id(IdSpecs.GenericIds.expected_id_schema(Post), keyword_list) ==
               {:ok, ~I<http://example.com/posts/lorem-ipsum>}

      assert Id.Schema.generate_id(
               IdSpecs.GenericIds.expected_id_schema(User),
               Example.user(EX.User0)
             ) ==
               {:ok, ~I<http://example.com/users/John%20Doe>}
    end

    test "with var_proc" do
      assert Id.Schema.generate_id(IdSpecs.VarProc.expected_id_schema(Example.VarProcA), %{
               name: "foo"
             }) ==
               {:ok, ~I<http://example.com/foo/FOO>}
    end

    # generation of UUID-based ids are tested in uuid_test.exs
  end
end
