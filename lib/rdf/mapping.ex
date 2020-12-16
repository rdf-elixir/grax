defmodule RDF.Mapping do
  alias RDF.Mapping.{Schema, Link, Loader, Validation, ToRDF}
  alias RDF.{IRI, BlankNode, Graph, Description}

  defmacro __using__(opts) do
    preload_default = Link.Preloader.normalize_spec(Keyword.get(opts, :preload), true)

    quote do
      import Schema, only: [schema: 1, schema: 2]

      @before_compile unquote(__MODULE__)

      @rdf_mapping_preload_default unquote(preload_default)
      def __preload_default__(), do: @rdf_mapping_preload_default
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def build(%IRI{} = id), do: do_build(id)
      def build(%BlankNode{} = id), do: do_build(id)

      def build(id) do
        if iri = IRI.new(id) do
          do_build(iri)
        else
          raise ArgumentError, "invalid id: #{inspect(id)}"
        end
      end

      def build!(id) do
        case build(id) do
          {:ok, mapping} -> mapping
          {:error, error} -> raise error
        end
      end

      defp do_build(id) do
        {:ok, %__MODULE__{__id__: id}}
      end

      @spec load(Graph.t() | Description.t(), IRI.coercible() | BlankNode.t(), opts :: Keyword) ::
              {:ok, struct} | {:error, any}
      def load(graph, id, opts \\ []) do
        with {:ok, initial} <- build(id) do
          Loader.call(__MODULE__, initial, graph, opts)
        end
      end

      @spec to_rdf(struct, opts :: Keyword) :: {:ok, Graph.t()} | {:error, any}
      def to_rdf(%__MODULE__{} = mapping, opts \\ []) do
        ToRDF.call(mapping, opts)
      end

      @spec validate(struct, opts :: Keyword) :: {:ok, struct} | {:error, ValidationError.t()}
      def validate(%__MODULE__{} = mapping, opts \\ []) do
        Validation.call(mapping, opts)
      end

      @spec validate!(struct, opts :: Keyword) :: struct
      def validate!(%__MODULE__{} = mapping, opts \\ []) do
        case validate(mapping, opts) do
          {:ok, _} -> mapping
          {:error, error} -> raise error
        end
      end

      @spec valid?(struct, opts :: Keyword) :: boolean
      def valid?(%__MODULE__{} = mapping, opts \\ []) do
        match?({:ok, _}, validate(mapping, opts))
      end
    end
  end
end
