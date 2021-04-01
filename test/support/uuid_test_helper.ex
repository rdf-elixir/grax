defmodule Grax.UuidTestHelper do
  import ExUnit.Assertions
  alias RDF.IRI

  def assert_valid_uuid(%IRI{} = iri, prefix, opts) do
    assert_valid_uuid(IRI.to_string(iri), prefix, opts)
  end

  def assert_valid_uuid(iri, prefix, opts) do
    assert String.starts_with?(iri, prefix)

    iri
    |> String.replace_prefix(prefix, "")
    |> assert_valid_uuid(opts)
  end

  def assert_valid_uuid(uuid, opts) do
    assert {:ok, info} = UUID.info(uuid)

    if expected_version = Keyword.get(opts, :version) do
      version = Keyword.get(info, :version)

      assert version == expected_version,
             "UUID version mismatch; expected #{expected_version}, but got #{version}"
    end

    if expected_type = Keyword.get(opts, :type) do
      type = Keyword.get(info, :type)

      assert type == expected_type,
             "UUID type mismatch; expected #{expected_type}, but got #{type}"
    end

    if expected_variant = Keyword.get(opts, :variant) do
      variant = Keyword.get(info, :variant)

      assert variant == expected_variant,
             "UUID type mismatch; expected #{expected_variant}, but got #{variant}"
    end
  end
end
