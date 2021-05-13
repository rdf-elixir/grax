defmodule Grax.Id.UrnTest do
  use Grax.TestCase

  alias Grax.Id
  alias Example.{IdSpecs, User, Post, Comment}

  test "URN ids" do
    assert {:ok, %RDF.IRI{value: "urn:example:John%20Doe"}} =
             IdSpecs.UrnIds.expected_id_schema(User)
             |> Id.Schema.generate_id(Example.user(EX.User0))

    assert {:ok, %RDF.IRI{value: "urn:example:lorem-ipsum"}} =
             IdSpecs.UrnIds.expected_id_schema(Post)
             |> Id.Schema.generate_id(Example.post())

    assert {:ok, %RDF.IRI{value: "urn:other:42"}} =
             IdSpecs.UrnIds.expected_id_schema(:integer)
             |> Id.Schema.generate_id(%{integer: 42})
  end

  test "hash URN ids" do
    assert {:ok, %RDF.IRI{value: "urn:sha1:4a197ebdd564ae83a8aedcf387da409c3d94bfbd"}} =
             IdSpecs.HashUrns.expected_id_schema(Post)
             |> Id.Schema.generate_id(Example.post())

    assert {:ok,
            %RDF.IRI{
              value:
                "urn:hash::sha256:a151ceb1711aad529a7704248f03333990022ebbfa07a7f04c004d70c167919f"
            }} =
             IdSpecs.HashUrns.expected_id_schema(Comment)
             |> Id.Schema.generate_id(Example.comment(EX.Comment1, depth: 0))
  end
end
