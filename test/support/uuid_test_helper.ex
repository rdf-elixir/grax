defmodule Grax.UuidTestHelper do
  import ExUnit.Assertions
  alias RDF.IRI

  alias Uniq.UUID

  def assert_valid_uuid(%IRI{} = iri, prefix, opts) do
    assert_valid_uuid(IRI.to_string(iri), prefix, opts)
  end

  def assert_valid_uuid(iri, "urn:" <> _ = prefix, opts) do
    assert String.starts_with?(iri, prefix)
    assert_valid_uuid(iri, opts)
  end

  def assert_valid_uuid(iri, prefix, opts) do
    assert String.starts_with?(iri, prefix)

    iri
    |> String.replace_prefix(prefix, "")
    |> assert_valid_uuid(opts)
  end

  def assert_valid_uuid(uuid, opts) do
    assert {:ok, uuid_info} = UUID.info(uuid)

    if expected_version = Keyword.get(opts, :version) do
      version = uuid_info.version

      assert version == expected_version,
             "UUID version mismatch; expected #{expected_version}, but got #{version}"
    end

    if expected_format = Keyword.get(opts, :format) do
      format = uuid_info.format

      assert format == expected_format,
             "UUID format mismatch; expected #{expected_format}, but got #{format}"
    end

    if expected_variant = Keyword.get(opts, :variant) do
      variant = uuid_info.variant

      assert variant == expected_variant,
             "UUID type mismatch; expected #{expected_variant}, but got #{variant}"
    end
  end
end
