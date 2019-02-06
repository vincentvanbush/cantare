defmodule Cantare.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cantare,
      version: "0.1.0",
      elixir: "~> 1.7",
      description: "Declarative, Ecto-aware authorization rules library for Elixir",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Cantare",
      source_url: "https://github.com/vincentvanbush/cantare"
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
      {:ecto, "~> 2.2.10"},
      {:ex_doc, only: :dev}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/vincentvanbush/scorify_elixir"}
    ]
  end
end
