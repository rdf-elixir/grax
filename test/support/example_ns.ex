defmodule Example.NS do
  use RDF.Vocabulary.Namespace

  defvocab EX,
    base_iri: "http://example.com/",
    terms: [],
    strict: false
end
