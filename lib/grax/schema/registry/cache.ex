defmodule Grax.Schema.Registry.Cache do
  @moduledoc """
  A cache for the `Grax.Schema.Registry`.

  The cached schema modules are encoded as an Elixir module with name `module_name/0`
  in a function `function_name/0` that is created with the Mix task `Mix.Tasks.Grax.CacheSchemaRegistry`
  at `path/0`.

  This can be used in cases when your application has a very large code base,
  causing a slow registry initialization and with that slows down the startup time
  of the application overall.
  """

  @default_path "priv/grax/schema_registry.cache"

  def path do
    # TODO: check presence of application configuration for a custom path?
    @default_path
  end

  @doc """
  Returns if the cache is present.

  This should be the case when the `Mix.Tasks.Grax.CacheSchemaRegistry` was
  used to generate the module.
  """
  def present? do
    File.exists?(path())
  end

  @doc """
  Returns the cached Grax schema modules.
  """
  def cached_schemas do
    if present?() do
      decode(path())
    end
  end

  @doc """
  Encoding of the list of registered Grax schema modules.
  """
  def encode(schema_modules) do
    {:ok, Enum.join(schema_modules, "\n")}
  end

  def decode(path \\ path()) do
    path
    |> File.stream!()
    |> Stream.map(&decode_module/1)
    |> Enum.to_list()
  end

  defp decode_module(line) do
    line
    |> String.trim()
    |> String.to_existing_atom()
  end
end
