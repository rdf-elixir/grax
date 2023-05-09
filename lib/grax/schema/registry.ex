defmodule Grax.Schema.Registry do
  @moduledoc """
  A global registry of Grax schemas and metadata about them.
  """
  use GenServer

  alias Grax.Schema.Registry.State

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def reset(opts \\ []) do
    GenServer.cast(__MODULE__, {:reset, opts})
  end

  def register(modules) do
    GenServer.cast(__MODULE__, {:register, modules})
  end

  def schema(iri) do
    GenServer.call(__MODULE__, {:schema, iri})
  end

  def inherited_schemas(schema) do
    GenServer.call(__MODULE__, {:inherited_schemas, schema})
  end

  @impl true
  def init(opts) do
    {:ok, State.build(opts)}
  end

  @impl true
  def handle_cast({:reset, opts}, _) do
    {:noreply, State.build(opts)}
  end

  @impl true
  def handle_cast({:register, modules}, state) do
    {:noreply, State.register(state, modules)}
  end

  @impl true
  def handle_call({:schema, iri}, _from, state) do
    {:reply, State.schema(state, iri), state}
  end

  @impl true
  def handle_call({:inherited_schemas, schema}, _from, state) do
    {:reply, State.inherited_schemas(state, schema), state}
  end
end
