defmodule Grax.Schema.Field do
  @moduledoc false

  defstruct [:name, :from_rdf]

  def new(name, opts) when is_atom(name) do
    struct!(__MODULE__,
      name: name,
      from_rdf: opts[:from_rdf]
    )
  end
end
