defmodule Grax.TestCase do
  use ExUnit.CaseTemplate

  alias RDF.{Dataset, Graph, Description, IRI}

  using do
    quote do
      alias RDF.{Dataset, Graph, Description, IRI, XSD, PrefixMap}
      alias RDF.NS.{RDFS, OWL}
      alias Example.NS.{EX, FOAF}

      import unquote(__MODULE__)
      import Grax.TestData
      import RDF, only: [iri: 1, literal: 1, bnode: 1]
      import RDF.Sigils

      @compile {:no_warn_undefined, Example.NS.EX}
      @compile {:no_warn_undefined, Example.NS.FOAF}
    end
  end
end
