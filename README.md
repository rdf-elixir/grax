# Grax

[![Hex.pm](https://img.shields.io/hexpm/v/grax.svg?style=flat-square)](https://hex.pm/packages/grax)
[![License](https://img.shields.io/hexpm/l/grax.svg)](https://github.com/rdf-elixir/grax/blob/master/LICENSE.md)

[![ExUnit Tests](https://github.com/rdf-elixir/grax/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/rdf-elixir/grax/actions/workflows/elixir-build-and-test.yml)
[![Dialyzer](https://github.com/rdf-elixir/grax/actions/workflows/elixir-dialyzer.yml/badge.svg)](https://github.com/rdf-elixir/grax/actions/workflows/elixir-dialyzer.yml)
[![Quality Checks](https://github.com/rdf-elixir/grax/actions/workflows/elixir-quality-checks.yml/badge.svg)](https://github.com/rdf-elixir/grax/actions/workflows/elixir-quality-checks.yml)


A light-weight graph data mapper which maps RDF graph data from [RDF.ex] data structures to schema-conform Elixir structs and vice versa.

For a guide and more information about Grax, and it's related projects, go to <https://rdf-elixir.dev/grax/>.

A migration guide to Grax v0.4 can be found [here](https://github.com/rdf-elixir/grax/wiki/Upgrading-to-Grax-v0.4).


## Usage

Let's assume we have a graph like this:

```ttl
{:ok, graph} =
  """
  @prefix : <http://example.com/> .
  @prefix schema: <https://schema.org/> .
  @prefix foaf: <http://xmlns.com/foaf/0.1/> .
  
  :User1
      schema:name "Jane" ;
      schema:email "jane@example.com" ;
      foaf:age 30 ;
      foaf:friend :User2.
  
  :Post1
      schema:author :User1 ;
      schema:name "Lorem" ;
      schema:articleBody """Lorem ipsum dolor sit amet, consectetur adipisicing elit. Provident, nihil, dignissimos. Nesciunt aut totam eius. Magnam quaerat modi vel sed, ipsam atque rem, eos vero ducimus beatae harum explicabo labore!""" .
    
    # ...
  """
  |> RDF.Turtle.read_string()
```

Grax allows us to define a schema for the mapping of this kind of data to Elixir structs.

```elixir
defmodule User do
  use Grax.Schema

  alias NS.{SchemaOrg, FOAF}

  schema SchemaOrg.Person do
    property name: SchemaOrg.name, type: :string
    property email: SchemaOrg.email, type: :string
    property age: FOAF.age, type: :integer
    
    link friends: FOAF.friend, type: list_of(User)
    link posts: -SchemaOrg.author, type: list_of(Post)

    field :password
  end
end

defmodule Post do
  use Grax.Schema

  alias NS.SchemaOrg

  schema SchemaOrg.BlogPosting do
    property title: SchemaOrg.name(), type: :string
    property content: SchemaOrg.articleBody(), type: :string

    link author: SchemaOrg.author(), type: User
  end
end
```

With that we can create an instance of our `User` struct from an `RDF.Graph`.

```elixir
iex> User.load(graph, EX.User1)
{:ok,
 %User{
   __id__: ~I<http://example.com/User1>,
   age: nil,
   email: ["jane@example.com", "jane@work.com"],
   friends: [],
   name: "Jane",
   password: nil,
   posts: [
     %Post{
       __id__: ~I<http://example.com/Post1>,
       author: ~I<http://example.com/User1>,
       content: "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Provident, nihil, dignissimos. Nesciunt aut totam eius. Magnam quaerat modi vel sed, ipsam atque rem, eos vero ducimus beatae harum explicabo labore!",
       title: "Lorem"
     }
   ]
 }}
```

And do some transformation on the struct and write it back to an RDF graph.

```elixir
user
|> Grax.put!(:age, user.age + 1)
|> Grax.to_rdf!()
|> RDF.Serialization.write_file!("user.ttl")
```


## Future Work

- I18n support (localization with language-tagged string literals)
- Storage adapters (e.g. accessing SPARQL endpoints directly and support for non-RDF-based graph databases)
- RDFS support (e.g. for class-based query builders)
- More preloading strategies (eg. pattern- and path-based preloading)


## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for details.


## Acknowledgements

The development of this project was sponsored by [NetzeBW](https://www.netze-bw.de/) for [NETZlive](https://www.netze-bw.de/unsernetz/netzinnovationen/digitalisierung/netzlive).


## Consulting

If you need help with your Elixir and Linked Data projects, just contact [NinjaConcept](https://www.ninjaconcept.com/) via <contact@ninjaconcept.com>.


## License and Copyright

(c) 2020-present Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.


[RDF.ex]:               https://github.com/rdf-elixir/rdf-ex
