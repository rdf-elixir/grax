%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Refactor.Nesting, false},
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        # TODO: reenable this when we've added API docs
        {Credo.Check.Readability.ModuleDoc, false},
      ],
    }
  ]
}
