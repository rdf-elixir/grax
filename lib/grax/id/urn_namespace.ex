defmodule Grax.Id.UrnNamespace do
  @type t :: %__MODULE__{
          nid: String.t(),
          string: String.t(),
          prefix: atom | nil
        }

  @enforce_keys [:nid, :string]
  defstruct [:nid, :string, :prefix]

  def new(nid, opts) do
    %__MODULE__{
      nid: nid,
      string: "urn:#{nid}:",
      prefix: Keyword.get(opts, :prefix)
    }
  end

  defimpl String.Chars do
    def to_string(namespace), do: namespace.string
  end
end
