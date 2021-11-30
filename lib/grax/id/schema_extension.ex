defmodule Grax.Id.Schema.Extension do
  alias Grax.Id

  @type t :: struct | module

  @callback init(Id.Schema.t(), opts :: keyword()) :: Id.Schema.t()

  @callback call(extension :: t, Id.Schema.t(), variables :: map, opts :: keyword()) ::
              {:ok, Id.Schema.t()} | {:error, any}

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__), only: [install: 2, extension_opt: 2]

      @impl unquote(__MODULE__)
      def init(id_schema, _opts), do: install(id_schema, __MODULE__)

      defoverridable init: 2
    end
  end

  @doc false
  def init(id_schema, extensions, opts)

  def init(id_schema, nil, _opts), do: id_schema

  def init(id_schema, extensions, opts) when is_list(extensions) do
    Enum.reduce(extensions, id_schema, fn extension, id_schema ->
      extension.init(id_schema, opts)
    end)
  end

  def init(id_schema, extension, opts), do: init(id_schema, List.wrap(extension), opts)

  @doc false
  def call(%{extensions: nil}, variables, _), do: {:ok, variables}

  def call(id_schema, variables, opts) do
    Enum.reduce_while(id_schema.extensions, {:ok, variables}, fn
      %type{} = extension, {:ok, variables} ->
        case type.call(extension, id_schema, variables, opts) do
          {:ok, _} = result -> {:cont, result}
          error -> {:halt, error}
        end

      extension, {:ok, variables} ->
        case extension.call(extension, id_schema, variables, opts) do
          {:ok, _} = result -> {:cont, result}
          error -> {:halt, error}
        end
    end)
  end

  def install(id_schema, extensions) do
    %Id.Schema{id_schema | extensions: List.wrap(id_schema.extensions) ++ List.wrap(extensions)}
  end

  def extension_opt(extension, opts) do
    Keyword.update(opts, :extensions, [extension], &(&1 ++ [extension]))
  end
end
