defmodule Grax.Schema.AdditionalStatements do
  @moduledoc false

  alias RDF.Description

  @pseudo_subject RDF.bnode("<pseudo_subject>")

  @empty %{}
  def empty, do: @empty

  def default(nil), do: @empty
  def default(class), do: new({RDF.type(), class})

  def new(predications) do
    RDF.description(@pseudo_subject, init: predications).predications
  end

  def description(%{__id__: subject, __additional_statements__: additional_statements}) do
    %Description{
      subject: subject,
      predications: additional_statements
    }
  end

  def clear(%schema{} = mapping, opts) do
    %{
      mapping
      | __additional_statements__:
          if(Keyword.get(opts, :clear_schema_class, false),
            do: empty(),
            else: schema.__additional_statements__()
          )
    }
  end

  def get(mapping, property) do
    mapping
    |> description()
    |> Description.get(property)
  end

  def update(mapping, fun) do
    %{mapping | __additional_statements__: fun.(description(mapping)).predications}
  end

  def add_filtered_description(mapping, statements, rejected_properties) do
    description = description(mapping)

    updated =
      Enum.reduce(statements, description, fn
        {_, p, o}, description ->
          if p in rejected_properties do
            description
          else
            Description.add(description, {p, o})
          end
      end)

    %{mapping | __additional_statements__: updated.predications}
  end
end
