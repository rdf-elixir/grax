defmodule Grax.Schema.CustomField do
  @moduledoc false

  defstruct [:name, :from_rdf, :default]

  alias Grax.Schema.DataProperty

  def new(schema, name, opts) when is_atom(name) do
    struct!(__MODULE__,
      name: name,
      default: opts[:default],
      from_rdf: DataProperty.normalize_custom_mapping_fun(opts[:from_rdf], schema)
    )
  end
end
