defmodule Grax.Schema.Loader do
  @moduledoc false

  alias Grax.Schema

  @type schema_module :: atom

  @doc """
  Loads all schemas in all code paths.
  """
  @spec load_all() :: [schema_module]
  def load_all, do: load_schemas(:code.get_path())

  @doc """
  Loads all schemas in the given `paths`.
  """
  @spec load_schemas([List.Chars.t()]) :: [schema_module]
  def load_schemas(dirs) do
    # We may get duplicate modules because we look through the
    # entire load path so make sure we only return unique modules.
    for dir <- dirs,
        file <- safe_list_dir(to_charlist(dir)),
        mod = schema_from_path(file),
        uniq: true,
        do: mod
  end

  defp safe_list_dir(path) do
    case File.ls(path) do
      {:ok, paths} -> paths
      {:error, _} -> []
    end
  end

  @prefix_size byte_size("Elixir.")
  @suffix_size byte_size(".beam")

  defp schema_from_path(filename) do
    base = Path.basename(filename)
    part = byte_size(base) - @prefix_size - @suffix_size

    case base do
      <<"Elixir.", rest::binary-size(part), ".beam">> ->
        mod = :"Elixir.#{rest}"
        Schema.schema?(mod) && mod

      _ ->
        nil
    end
  end

  @doc """
  Returns all loaded schema modules.

  Modules that are not yet loaded won't show up.
  Check `load_all/0` if you want to preload all schemas.
  """
  @spec all_modules() :: [schema_module]
  def all_modules do
    for {module, _} <- :code.all_loaded(), Schema.schema?(module), do: module
  end
end
