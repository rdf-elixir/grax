locals_without_parens = [
  # Grax.Schema
  property: 1,
  property: 2,
  property: 3,
  link: 1,
  link: 3,
  field: 1,
  field: 2,

  # Grax.Id.Spec
  namespace: 2,
  base: 2,
  blank_node: 1,
  id_schema: 2,
  id: 1,
  id: 2,
  id: 3,
  hash: 1,
  hash: 2,
  uuid: 1,
  uuid: 2,
  uuid1: 1,
  uuid1: 2,
  uuid3: 1,
  uuid3: 2,
  uuid4: 1,
  uuid4: 2,
  uuid5: 1,
  uuid5: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{bench,config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:rdf],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
