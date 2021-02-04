defmodule Grax.Schema.CustomField do
  @moduledoc false

  defstruct [:name, :from_rdf, :default]

  def new(name, opts) when is_atom(name) do
    struct!(__MODULE__,
      name: name,
      default: opts[:default],
      from_rdf: opts[:from_rdf]
    )
  end
end
