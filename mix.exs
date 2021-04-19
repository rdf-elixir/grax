defmodule Grax.MixProject do
  use Mix.Project

  @repo_url "https://github.com/rdf-elixir/grax"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :grax,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

      # Hex
      package: package(),
      description: description(),

      # Docs
      name: "Grax",
      docs: [
        main: "Grax",
        source_url: @repo_url,
        source_ref: "v#{@version}",
        extras: ["CHANGELOG.md"]
      ],

      # ExCoveralls
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp description do
    """
    A light-weight RDF graph data mapper for Elixir.
    """
  end

  defp package do
    [
      maintainers: ["Marcel Otto"],
      licenses: ["MIT"],
      links: %{
        "Homepage" => "https://rdf-elixir.dev",
        "GitHub" => @repo_url,
        "Changelog" => @repo_url <> "/blob/master/CHANGELOG.md"
      },
      files: ~w[lib priv mix.exs .formatter.exs VERSION *.md]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rdf, ">= 0.9.2"},
      {:yuri_template, "~> 1.1"},
      {:elixir_uuid, "~> 1.2", optional: true},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
