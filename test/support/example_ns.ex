defmodule Example.NS do
  use RDF.Vocabulary.Namespace

  defvocab EX,
    base_iri: "http://example.com/",
    terms: [],
    strict: false

  defvocab FOAF,
    base_iri: "http://xmlns.com/foaf/0.1/",
    terms: [:Person, :foaf, :mbox],
    strict: false
end
