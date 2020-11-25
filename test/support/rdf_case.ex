defmodule RDF.Test.Case do
  use ExUnit.CaseTemplate

  alias RDF.{Dataset, Graph, Description, IRI}

  using do
    quote do
      alias RDF.{Dataset, Graph, Description, IRI, XSD, PrefixMap, PropertyMap}
      alias RDF.NS.{RDFS, OWL}
      alias Example.NS.EX

      import unquote(__MODULE__)
      import RDF.Mapping.TestData
      import RDF, only: [iri: 1, literal: 1, bnode: 1]
      import RDF.Sigils

      @compile {:no_warn_undefined, Example.NS.EX}
    end
  end
end
