defmodule Grax.Id.Types.HashTest do
  use Grax.TestCase

  alias Grax.Id
  alias Example.{IdSpecs, User, Post, Comment}

  import RDF.Sigils

  test "hash id" do
    assert {:ok,
            ~I<http://example.com/f1ca4b7d9f704857b16b6dfef392146c8582930022217359e33cf94bf67a83ed162bdd47d7b51871d4a73083533bf2456ffcac6fca88064af426835f62d5f3fb>} =
             IdSpecs.Hashing.expected_id_schema(User)
             |> Id.Schema.generate_id(Example.user(EX.User0))

    assert {:ok,
            ~I<http://example.com/551a88bc357556f1965a1f386a3883ecf6a0ca337c898387a977862c0e217d3a>} =
             IdSpecs.Hashing.expected_id_schema(Post)
             |> Id.Schema.generate_id(Example.post())

    assert {:ok, ~I<http://example.com/7fb55ed0b7a30342ba6da306428cae04>} =
             IdSpecs.Hashing.expected_id_schema(Comment)
             |> Id.Schema.generate_id(Example.comment(EX.Comment1, depth: 1))
  end

  test "when no value for the name present" do
    assert IdSpecs.Hashing.expected_id_schema(Post)
           |> Id.Schema.generate_id(content: nil) ==
             {:error, "no :content value for hashing present"}
  end

  test "with var_mapping" do
    assert {:ok, ~I<http://example.com/feab40e1fca77c7360ccca1481bb8ba5f919ce3a>} =
             Id.Schema.generate_id(IdSpecs.VarMapping.expected_id_schema(Example.VarMappingC), %{
               name: "foo"
             })
  end
end
