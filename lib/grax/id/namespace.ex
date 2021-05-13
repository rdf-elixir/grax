defmodule Grax.Id.Namespace do
  @type t :: %__MODULE__{
          parent: t | nil,
          uri: String.t(),
          prefix: atom | nil
        }

  @enforce_keys [:uri]
  defstruct [:parent, :uri, :prefix]

  def new(parent, segment, opts) do
    %__MODULE__{
      uri: initialize_uri(parent, segment),
      parent: parent,
      prefix: Keyword.get(opts, :prefix)
    }
  end

  defp initialize_uri(nil, uri), do: uri
  defp initialize_uri(%__MODULE__{} = parent, segment), do: uri(parent) <> segment

  def uri(%__MODULE__{} = namespace), do: namespace.uri

  defimpl String.Chars do
    def to_string(namespace), do: Grax.Id.Namespace.uri(namespace)
  end
end
