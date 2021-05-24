defmodule Grax.Id.Namespace do
  alias Grax.Id.UrnNamespace

  @type t :: %__MODULE__{
          parent: t | nil,
          uri: String.t(),
          prefix: atom | nil,
          options: Keyword.t() | nil
        }

  @enforce_keys [:uri]
  defstruct [:parent, :uri, :prefix, :options]

  def new(parent, segment, opts) do
    {prefix, opts} = Keyword.pop(opts, :prefix)

    %__MODULE__{
      uri: initialize_uri(parent, segment),
      parent: parent,
      prefix: prefix,
      options: unless(Enum.empty?(opts), do: opts)
    }
  end

  defp initialize_uri(nil, uri), do: uri
  defp initialize_uri(%__MODULE__{} = parent, segment), do: uri(parent) <> segment

  def uri(%__MODULE__{} = namespace), do: namespace.uri

  def option(%__MODULE__{} = namespace, key) do
    get_option(namespace.options, namespace.parent, key)
  end

  def option(%UrnNamespace{} = namespace, key) do
    get_option(namespace.options, nil, key)
  end

  defp get_option(nil, nil, _), do: nil
  defp get_option(nil, parent, key), do: option(parent, key)
  defp get_option(options, nil, key), do: Keyword.get(options, key)
  defp get_option(options, parent, key), do: get_option(options, nil, key) || option(parent, key)

  defimpl String.Chars do
    def to_string(namespace), do: Grax.Id.Namespace.uri(namespace)
  end
end
