defmodule Grax.TestCase do
  use ExUnit.CaseTemplate

  alias RDF.{Dataset, Graph, Description, IRI}

  using do
    quote do
      alias RDF.{Dataset, Graph, Description, IRI, XSD, PrefixMap}
      alias RDF.NS.{RDFS, OWL}
      alias Example.NS.{EX, FOAF}

      import unquote(__MODULE__)
      import Grax.TestData
      import RDF, only: [iri: 1, literal: 1, bnode: 1]
      import RDF.Sigils

      @compile {:no_warn_undefined, Example.NS.EX}
      @compile {:no_warn_undefined, Example.NS.FOAF}
    end
  end

  def order_independent({:ok, %Example.Datatypes{} = datatypes}),
    do:
      {:ok,
       %{
         datatypes
         | integers: Enum.sort(datatypes.integers),
           numerics: Enum.sort(datatypes.numerics)
       }}

  def order_independent({:error, %Grax.ValidationError{errors: errors} = error}),
    do: {:error, %{error | errors: Enum.sort(errors)}}

  def order_independent({:error, %Grax.Schema.DetectionError{candidates: candidates} = error}),
    do: {:error, %{error | candidates: Enum.sort(candidates)}}

  def order_independent({:ok, elements}), do: {:ok, Enum.sort(elements)}
  def order_independent(elements), do: Enum.sort(elements)

  defmacro assert_order_independent({:==, _, [left, right]}) do
    quote do
      assert order_independent(unquote(left)) == order_independent(unquote(right))
    end
  end
end
