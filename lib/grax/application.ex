defmodule Grax.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Grax.Id.Counter.Supervisor,
      {Registry, keys: :unique, name: Grax.Id.Counter.registry()}
    ]

    opts = [strategy: :one_for_one, name: Grax.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
