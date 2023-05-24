# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## Unreleased

### Added

- Grax schema mapping functions `from/1` and `from!/1` on Grax schema modules,
  which allows to map one schema struct to another
- The class mapping on a union type can now also be provided as a list of
  `{class_iri, schema}` tuples or just Grax schemas, for those which are
  associated with a class IRI with a class declaration.
- the `:on_rdf_type_mismatch` option is now supported on all types of links
  (previously it was available on union links only)
- `Grax.Schema.schema?/1` and `Grax.Schema.struct?/1` to determine whether a given
  module or struct is a Grax schema resp. Grax schema struct
- `Grax.schema/1` to get the schema(s) of a given class IRI
- `Grax.Schema.schema?/1` to check if a given module or struct is a `Grax.Schema`
- `Grax.Schema.inherited_from?/1` to check if a given module or struct is 
  inherited from another `Grax.Schema`
- `Grax.delete_additional_predicates/2` to delete all additional statements

### Changed

- Links now have become polymorphic, i.e. the most specific
  inherited schema matching one of the types of a linked resource is used.
  Opting-out to non-polymorphic behaviour is possible by setting the
  `:polymorphic` option to `false` on a `link` definition. However, the
  non-polymorphic behaviour still differs slightly from the previous version,
  in that, when `:on_type_mismatch` is set to `:error`, preloading of an RDF  
  resource which is not typed with the class of the specified schema, but the
  class of an inherited schema, no longer leads to an error.
- Preloading of union links whose schemas are in an inheritance relationship
  are resolved to the most specific class and no longer result in an
  `:multiple_matches` when the resource is typed also with the broader classes.
- The internal representation of the `__additional_statements__` field of Grax 
  schema structs was changed to use now the same format as the internal
  `predications` field of `RDF.Description`s. This allows various optimizations 
  and a richer API for accessing the additional statements, e.g. all the 
  functions to update the additional statements like `Grax.add_additional_statements/2`
  now can handle the multitude of inputs as the respective `RDF.Description`
  counterpart. Unfortunately, this brings two additional breaking changes:
  - You no longer can pass the contents of the `__additional_statements__` 
    field of one Grax schema as the additional statements to another one.
    You should instead pass the result of `Grax.additional_statements/1` now.
  - You no longer can use `nil` values on a property with `Grax.put_additional_statements/2`
    to remove statements with this property. You must use the new 
    `Grax.delete_additional_predicates/2` function for this now.
- Rename `:on_type_mismatch` link option to `:on_rdf_type_mismatch` to make it
  clearer that it is only relevant during preloading from RDF data
- "heterogeneous link properties" are now called "union link properties"
  (since this name didn't appear in the code, this change only affects the documentation)
- Rename `Grax.Schema.InvalidProperty` to `Grax.Schema.InvalidPropertyError` for
  consistency reasons

### Fixed

- a bug when preloading a nested schema with union links without values
- union links weren't validated properly


[Compare v0.3.5...HEAD](https://github.com/rdf-elixir/grax/compare/v0.3.5...HEAD)



## v0.3.5 - 2023-01-18

### Fixed

- additional statements with objects in MapSets weren't handled properly, which
  is critical in particular, because the objects in additional statements are kept
  in MapSets internally, which meant additional statements from one schema couldn't
  be passed to another schema
- raise a proper error when preloading of a link fails because a literal is given


[Compare v0.3.4...v0.3.5](https://github.com/rdf-elixir/grax/compare/v0.3.4...v0.3.5)



## v0.3.4 - 2022-11-03

This version is upgrades to RDF.ex 1.0.

Elixir versions < 1.11 are no longer supported


### Fixed

- a bug when reading the counter of a `Grax.Id.Counter.TextFile/2` under Elixir 1.14


[Compare v0.3.3...v0.3.4](https://github.com/rdf-elixir/grax/compare/v0.3.3...v0.3.4)



## v0.3.3 - 2022-06-29

### Added

- `Grax.delete_additional_statements/2`

### Fixed

- `to_rdf/2` failed when an inverse property was not a list (#1)


[Compare v0.3.2...v0.3.3](https://github.com/rdf-elixir/grax/compare/v0.3.2...v0.3.3)



## v0.3.2 - 2022-01-28

### Added

- `on_load/3` and `on_to_rdf/3` callbacks on `Grax.Schema`s
- `Grax.Schema`s now have an `__additional_statements__` field, which holds
  additional statements about the resource, which are not mapped to schema 
  fields, but should be mapped back to RDF
- `Grax.to_rdf!/2` bang variant of `Grax.to_rdf/2` 


[Compare v0.3.1...v0.3.2](https://github.com/rdf-elixir/grax/compare/v0.3.1...v0.3.2)



## v0.3.1 - 2021-07-16

### Added

- support for counter-based Grax ids 
- support for blank nodes as Grax ids 


### Optimized

- improved Grax id schema lookup performance


[Compare v0.3.0...v0.3.1](https://github.com/rdf-elixir/grax/compare/v0.3.0...v0.3.1)



## v0.3.0 - 2021-05-26

### Added

- Grax ids - see the [new chapter in the Grax guide](https://rdf-elixir.dev/grax/ids.html)
  for more on this bigger feature


### Changed

- not loaded links are no longer represented with `Grax.Link.NotLoaded` structs,
  but with `RDF.IRI` or `RDF.BlankNode`s instead 
- the value of link properties can be given as plain `RDF.IRI`, `RDF.BlankNode`
  values or as vocabulary namespace terms on `Grax.new` and `Grax.build` 
- the value of properties with type `:iri` can be given as vocabulary namespace
  terms on `Grax.new` and `Grax.build`


[Compare v0.2.0...v0.3.0](https://github.com/rdf-elixir/grax/compare/v0.2.0...v0.3.0)



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
