# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## Unreleased

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

### Changed

- the way in which list types are defined in a schema has been change from putting the
  base type in square bracket to using one of the new `list_of/1` or `list/0` type builder
  functions
- the default value of link properties has been changed to `nil` respective the empty list
  (previously it was a `Grax.Link.NotLoaded` struct, which is now set explicitly 
  during loading)
- failing `:required` requirements result in a `Grax.Schema.CardinalityError` instead
  of a `Grax.Schema.RequiredPropertyMissing` exception


[Compare v0.1.0...HEAD](https://github.com/rdf-elixir/grax/compare/v0.1.0...HEAD)



## v0.1.0 - 2021-01-06

Initial release
