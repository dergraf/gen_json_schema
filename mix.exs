defmodule GenJsonSchema.MixProject do
  use Mix.Project

  def project do
    [
      app: :gen_json_schema,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "gen_json_schema",
      description: "Generate a JSON Schema from an Elixir Typespec",
      package: [
        name: "gen_json_schema",
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => "https://github.com/dergraf/gen_json_schema"}
      ],
      source_url: "https://github.com/dergraf/gen_json_schema"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yaml_elixir, "~> 2.11"},
      {:recase, "~> 0.8"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
