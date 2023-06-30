# credo:disable-for-this-file Credo.Check.Refactor.WithClauses
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

    path = Cache.path()

    with Mix.shell().info("Generating Grax schema registry cache ..."),
         {:ok, encoded_cache} <- Cache.encode(schemas),
         Mix.shell().info("Writing Grax schema registry cache file #{path}"),
         :ok <- write_cache(encoded_cache, path) do
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

  defp write_cache(encoded_cache, path) do
    # TODO: How to handle umbrellas?
    with :ok <- path |> Path.dirname() |> File.mkdir_p() do
      File.write(path, encoded_cache)
    end
  end
end
