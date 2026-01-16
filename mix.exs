defmodule Grax.MixProject do
  use Mix.Project

  @repo_url "https://github.com/rdf-elixir/grax"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :grax,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      aliases: aliases(),

      # Dialyzer
      dialyzer: dialyzer(),

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
      test_coverage: [tool: ExCoveralls]
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
      extra_applications: [:logger, :crypto],
      mod: {Grax.Application, []}
    ]
  end

  defp deps do
    [
      rdf_ex_dep(:rdf, "~> 2.1"),
      {:uniq, "~> 0.6"},
      {:yuri_template, "~> 1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      # This dependency is needed for ExCoveralls when OTP < 25
      {:castore, "~> 1.0", only: :test},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end

  defp rdf_ex_dep(dep, version) do
    case System.get_env("RDF_EX_PACKAGES_SRC") do
      "LOCAL" -> {dep, path: "../#{dep}"}
      _ -> {dep, version}
    end
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      ignore_warnings: ".dialyzer_ignore.exs",
      # Error out when an ignore rule is no longer useful so we can remove it
      list_unused_filters: true
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp aliases do
    [
      check: [
        "clean",
        "deps.unlock --check-unused",
        "compile --all-warnings --warnings-as-errors",
        "format --check-formatted",
        "test --warnings-as-errors",
        "credo"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
