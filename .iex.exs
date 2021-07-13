import RDF.Sigils
import RDF.Guards

alias RDF.NS
alias RDF.NS.{RDFS, OWL, SKOS}

alias RDF.{
  Term,
  IRI,
  BlankNode,
  Literal,
  XSD,

  Triple,
  Quad,
  Statement,

  Description,
  Graph,
  Dataset,

  PrefixMap,
  PropertyMap
}

alias RDF.BlankNode, as: BNode

alias RDF.{NTriples, NQuads, Turtle}

alias Decimal, as: D

c "test/support/example_ns.ex"
c "test/support/example_id_specs.ex"
c "test/support/example_schemas.ex"

alias Example.NS.EX
