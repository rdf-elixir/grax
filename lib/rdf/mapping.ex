defmodule RDF.Mapping do
  alias RDF.Mapping.{Schema, FromRDF, ToRDF}
  alias RDF.{IRI, Graph, Description}

  defmacro __using__(opts) do
    quote do
      import Schema, only: [schema: 1]

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defp __new__(iri) do
        %__MODULE__{__iri__: IRI.to_string(iri)}
      end

      @spec iri(struct) :: IRI.t()
      def iri(%__MODULE__{} = mapping), do: mapping.__iri__

      @spec from_rdf(Graph.t() | Description.t(), IRI.coercible(), opts :: Keyword) ::
              {:ok, struct} | {:error, any}
      def from_rdf(graph, iri, opts \\ []) do
        case __new__(iri) do
          %__MODULE__{} = initial ->
            FromRDF.call(__MODULE__, initial, iri, graph, opts)

          bad ->
            {:error, "bad result of #{__MODULE__}.__new__/1: #{inspect(bad)}"}
        end
      end

      @spec to_rdf(struct, opts :: Keyword) :: {:ok, Graph.t()} | {:error, any}
      def to_rdf(%__MODULE__{} = mapping, opts \\ []) do
        ToRDF.call(mapping, opts)
      end
    end
  end
end
