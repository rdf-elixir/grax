locals_without_parens = [
  property: 1,
  property: 2,
  property: 3,
  link: 1,
  link: 3
]

[
  inputs: ["{mix,.formatter}.exs", "{bench,config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:rdf],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
