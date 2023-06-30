defmodule Grax.Schema.Registry.Cache do
  @moduledoc """
  A cache for the `Grax.Schema.Registry`.

  The cached schema modules are encoded as an Elixir module with name `module_name/0`
  in a function `function_name/0` that is created with the Mix task `Mix.Tasks.Grax.CacheSchemaRegistry`
  at `path/0`.

  This can be used in cases when your application has a very large code base,
  causing a slow registry initialization and with that slows down the startup time
  of the application.
  """

  @default_path "lib/grax/schema_registry_cache.ex"

  def path do
    # TODO: check presence of application configuration for a custom path?
    @default_path
  end

  @module_name Grax.SchemaRegistryCache

  def module_name do
    # TODO: check presence of application configuration for a custom cache module name?
    @module_name
  end

  @function_name :all_grax_schemas

  def function_name(), do: @function_name

  @doc """
  Returns if the cache is present.

  This should be the case when the `Mix.Tasks.Grax.CacheSchemaRegistry` was
  used to generate the module.
  """
  def present? do
    case Code.ensure_compiled(module_name()) do
      {:module, mod} -> function_exported?(mod, function_name(), 0)
      _ -> false
    end
  end

  @doc """
  Returns the cached Grax schema modules.
  """
  def cached_schemas do
    if present?() do
      apply(module_name(), function_name(), [])
    end
  end

  @doc """
  Encoding of the list of registered Grax schema modules.
  """
  def encode(
        schema_modules,
        cache_module_name \\ module_name(),
        cache_function_name \\ function_name()
      ) do
    code = """
    defmodule #{cache_module_name} do
      def #{cache_function_name} do
        [
          #{Enum.join(schema_modules, ",\n      ")}
        ]
      end
    end
    """

    {:ok, code}
  end
end
