# Grax

A light-weight RDF graph data mapper which maps RDF graph data from [RDF.ex] data structures to schema-conform Elixir structs for the domain models of an RDF-based application.

For a guide and more information about Grex and it's related projects, go to <https://rdf-elixir.dev>.


## Example 

```elixir
defmodule User do
  use Grax.Entity

  alias NS.{SchemaOrg, FOAF, EX}

  schema SchemaOrg.Person do
    property name: SchemaOrg.name, type: :string
    property email: SchemaOrg.email, type: :string
    property age: FOAF.age, type: :integer
    property password: nil
    
    link friends: FOAF.friend, type: [User]
    link posts: -SchemaOrg.author, type: [Post]
  end
end

user =
  "user.ttl"
  |> RDF.Serialization.read_file!()
  |> User.load!(EX.User1)

user
|> Grax.put!(:age, user.age + 1)
|> Grax.to_rdf!
|> RDF.Serialization.write_file!("user.ttl")
```


## Future Work

- Storage backend adapter, eg.
    -  a SPARQL.Client adapter for mappings of RDF graph data from SPARQL endpoints to schema-conform Elixir structs
    -  a LDP.Client for mappings of RDF graph data from LDP resources and collections to schema-conform Elixir structs
- RDFS-support
    - auto-generated filtering of links to resources of a certain `rdf:type`
    - auto-generated class-based query builders


## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for details.


## Acknowledgements

The development of this project was sponsored by [NetzeBW](https://www.netze-bw.de/) for [NETZlive](https://www.netze-bw.de/unsernetz/netzinnovationen/digitalisierung/netzlive).


## License and Copyright

(c) 2020-present Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.


[RDF.ex]:               https://github.com/rdf-elixir/rdf-ex
