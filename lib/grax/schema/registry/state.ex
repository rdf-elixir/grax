defmodule Grax.Schema.Registry.State do
  @moduledoc false

  alias Grax.Schema
  alias Grax.Schema.Loader

  require Logger

  defstruct schemas_by_iri: %{}

  def build(additional \\ []) do
    %__MODULE__{}
    |> register(Loader.load_all())
    |> register(additional)
  end

  def register(state, modules) when is_list(modules) do
    Enum.reduce(modules, state, &register(&2, &1))
  end

  def register(state, module) do
    if Schema.schema?(module) do
      %__MODULE__{
        state
        | schemas_by_iri: add_schema_iri(state.schemas_by_iri, module, module.__class__())
      }
    else
      state
    end
  end

  defp add_schema_iri(schemas_by_iri, _, nil), do: schemas_by_iri

  defp add_schema_iri(schemas_by_iri, schema, iri) do
    Map.update(schemas_by_iri, RDF.iri(iri), schema, &[schema | List.wrap(&1)])
  end

  def schema(%{schemas_by_iri: schemas_by_iri}, iri) do
    schemas_by_iri[iri]
  end
end
