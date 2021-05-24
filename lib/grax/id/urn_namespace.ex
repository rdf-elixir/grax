defmodule Grax.Id.UrnNamespace do
  @type t :: %__MODULE__{
          nid: String.t(),
          string: String.t(),
          prefix: atom | nil,
          options: Keyword.t() | nil
        }

  @enforce_keys [:nid, :string]
  defstruct [:nid, :string, :prefix, :options]

  def new(nid, opts) do
    {prefix, opts} = Keyword.pop(opts, :prefix)

    %__MODULE__{
      nid: nid,
      string: "urn:#{nid}:",
      prefix: prefix,
      options: unless(Enum.empty?(opts), do: opts)
    }
  end

  defimpl String.Chars do
    def to_string(namespace), do: namespace.string
  end
end
