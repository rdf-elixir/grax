# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## Unreleased

### Added

- heterogeneous link properties which can link different types of resources
  to different schemas
- schema inheritance
- support for custom `:from_rdf` mappings on custom fields  

### Changed

- the default value of link properties has been changed to `nil` respective the empty list
  (previously it was a `Grax.Link.NotLoaded` struct, which is now set explicitly 
  during loading)


[Compare v0.1.0...HEAD](https://github.com/rdf-elixir/grax/compare/v0.1.0...HEAD)



## v0.1.0 - 2021-01-06

Initial release
