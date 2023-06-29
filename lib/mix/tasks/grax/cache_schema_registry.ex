defmodule Mix.Tasks.Grax.CacheSchemaRegistry do
  @moduledoc """
  Generates a cache file for the Grax schema registry
  """

  use Mix.Task

  alias Grax.Schema.Registry.State
  alias Grax.Schema.Registry.Cache

  @shortdoc "Generates a cache file for the Grax schema registry"

  def run(_args) do
    Mix.Task.run("compile")

    Mix.shell().info("Caching Grax schema modules ...")

    Mix.shell().info("Searching Grax schema modules ...")

    schemas = State.build() |> State.all_schemas()
    Mix.shell().info("#{Enum.count(schemas)} Grax schema modules found")

    cache_module_name = Cache.module_name()
    path = Cache.path()

    with Mix.shell().info("Generating Grax schema registry cache module #{cache_module_name}..."),
         {:ok, cache_module} <- Cache.encode(schemas, cache_module_name),
         Mix.shell().info("Writing Grax schema registry cache file #{path}"),
         :ok <- write_cache(cache_module, path) do
      Mix.shell().info("Done")
      :ok
    else
      {:error, exception} = error ->
        Mix.shell().error("Caching failed with #{inspect(exception)}")
        error

      error ->
        Mix.shell().error("Caching failed with fatal error: #{inspect(error)}")
        raise error
    end
  end

  defp write_cache(code, path) do
    # TODO: How to handle umbrellas?
    with :ok <- path |> Path.dirname() |> File.mkdir_p() do
      File.write(path, code)
    end
  end
end
