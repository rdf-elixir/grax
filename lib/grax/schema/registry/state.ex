defmodule Grax.Schema.Registry.State do
  @moduledoc false

  alias Grax.Schema
  alias Grax.Schema.Loader

  require Logger

  defstruct schemas_by_iri: %{}, schemas_without_iri: []

  def build(additional \\ []) do
    %__MODULE__{}
    |> register(Loader.load_all())
    |> register(additional)
  end

  def register(state, modules) when is_list(modules) do
    Enum.reduce(modules, state, &register(&2, &1))
  end

  def register(state, module) do
    cond do
      not Schema.schema?(module) ->
        state

      class_iri = module.__class__() ->
        %__MODULE__{
          state
          | schemas_by_iri: add_schema_iri(state.schemas_by_iri, module, class_iri)
        }

      true ->
        %__MODULE__{state | schemas_without_iri: [module | state.schemas_without_iri]}
    end
  end

  defp add_schema_iri(schemas_by_iri, _, nil), do: schemas_by_iri

  defp add_schema_iri(schemas_by_iri, schema, iri) do
    Map.update(schemas_by_iri, RDF.iri(iri), schema, &[schema | List.wrap(&1)])
  end

  def schema(%{schemas_by_iri: schemas_by_iri}, iri) do
    schemas_by_iri[iri]
  end

  def all_schemas(%{schemas_by_iri: schemas_by_iri, schemas_without_iri: schemas_without_iri}) do
    Enum.uniq(
      schemas_without_iri ++
        (schemas_by_iri
         |> Map.values()
         |> Enum.flat_map(&List.wrap/1))
    )
  end
end
