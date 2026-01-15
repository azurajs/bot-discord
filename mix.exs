defmodule AzuraJS.MixProject do
  use Mix.Project

  def project do
    [
      app: :azurajs_bot,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AzuraJS.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:nostrum, "~> 0.10"},
      {:dotenvy, "~> 1.0.0"},
      {:telemetry, "~> 1.0"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:openai, "~> 0.6.2"}
    ]
  end
end
