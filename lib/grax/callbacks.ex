defmodule Grax.Callbacks do
  alias Grax.Schema
  alias RDF.{Graph, Description}

  @callback on_load(Schema.t(), Graph.t() | Description.t(), opts :: keyword()) ::
              {:ok, Schema.t()} | {:error, any}

  @callback on_to_rdf(Schema.t(), Graph.t(), opts :: keyword()) ::
              {:ok, Graph.t()} | {:error, any}

  @callback on_validate(Schema.t(), opts :: keyword()) :: :ok | {:error, any}
end
