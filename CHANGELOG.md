# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## Unreleased

### Changed

- not loaded links are no longer represented with `Grax.Link.NotLoaded` structs,
  but with `RDF.IRI` or `RDF.BlankNode`s instead 
- the value of link properties can be given as plain `RDF.IRI`, `RDF.BlankNode`
  values or as vocabulary namespace terms on `Grax.new` and `Grax.build` 
- the value of properties with type `:iri` can be given as vocabulary namespace
  terms on `Grax.new` and `Grax.build`


[Compare v0.2.0...HEAD](https://github.com/rdf-elixir/grax/compare/v0.2.0...HEAD)



## v0.2.0 - 2021-03-16

### Added

- heterogeneous link properties which can link different types of resources
  to different schemas
- schema inheritance
- support for cardinality constraints on properties
- support for `:required` on link properties  
- support for custom `:from_rdf` mappings on custom fields  
- support for custom mappings in separate modules
- the `build` functions can now be called with a single map when the map contains
  an id an `:__id__` field
- `:context` field on `Grax.ValidationError` exception with more context specific information

### Changed

- the way in which list types are defined in a schema has been changed from putting the
  base type in square bracket to using one of the new `list_of/1` or `list/0` type builder
  functions
- the default value of link properties has been changed to `nil` respective the empty list
  (previously it was a `Grax.Link.NotLoaded` struct, which is now set explicitly 
  during loading)
- in the `Grax.build` and `Grax.put` functions duplicates in the given values are ignored 
- in the `Grax.build` and `Grax.put` functions a single value in a list for a non-list 
  property will now be extracted, instead of leading to a validation error
- failing `:required` requirements result in a `Grax.Schema.CardinalityError` instead
  of a `Grax.Schema.RequiredPropertyMissing` exception
- the opts on `Grax.to_rdf/2` are now passed-through to the `RDF.Graph.new/2` constructor
  allowing to set the name of the graph, prefixes etc.


[Compare v0.1.0...v0.2.0](https://github.com/rdf-elixir/grax/compare/v0.1.0...v0.2.0)



## v0.1.0 - 2021-01-06

Initial release
