defmodule Grax.Id.Namespace do
  @enforce_keys [:segment]
  defstruct [:parent, :segment, :prefix, :base]

  def new(segment, opts) do
    %__MODULE__{
      segment: segment,
      parent: Keyword.get(opts, :parent),
      prefix: Keyword.get(opts, :prefix),
      base: Keyword.get(opts, :base, false)
    }
  end

  def uri(%__MODULE__{parent: nil, segment: segment}), do: segment
  def uri(%__MODULE__{parent: parent, segment: segment}), do: uri(parent) <> segment

  def iri(namespace), do: namespace |> uri() |> RDF.iri()
end
