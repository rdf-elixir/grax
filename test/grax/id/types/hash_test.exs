defmodule Grax.Id.Types.HashTest do
  use Grax.TestCase

  alias Grax.Id
  alias Example.{IdSpecs, User, Post, Comment}

  import RDF.Sigils

  test "hash id" do
    assert {:ok,
            ~I<http://example.com/9a4db41ca7f4b12aaaf554c8f9044a0e22bd969890fb03fc0af4e05221745e15d0ce8cd232d22ddee999e9c4faaee5b46e90ac6af21c9a5a6e0ca005a617db93>} =
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

  test "with var_proc" do
    assert {:ok, ~I<http://example.com/feab40e1fca77c7360ccca1481bb8ba5f919ce3a>} =
             Id.Schema.generate_id(IdSpecs.VarProc.expected_id_schema(Example.VarProcC), %{
               name: "foo"
             })
  end
end
