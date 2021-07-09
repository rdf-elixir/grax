defmodule Grax.Id.Counter.Supervisor do
  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_counter(adapter, name) do
    DynamicSupervisor.start_child(__MODULE__, {adapter, name})
  end

  def start_counter!(adapter, name) do
    case start_counter(adapter, name) do
      {:ok, pid} -> pid
      {:error, error} -> raise error
    end
  end
end
