defmodule Flub.Mixfile do
  use Mix.Project

  @version "0.9.0"
  @repo_url "https://github.com/meyercm/shorter_maps"

  def project do
    [
      app: :flub,
      version: @version,
      elixir: "~> 1.2",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      package: hex_package,
      description: "Flub does Pub. Flub does Sub. Flub does PubSub, bub."
    ]
  end

  def application do
    [applications: [:logger, :ets_owner],
     mod: {Flub.App, []}]
  end

  defp hex_package do
    [maintainers: ["Chris Meyer"],
     licenses: ["MIT"],
     links: %{"GitHub" => @repo_url}]
  end

  defp deps do
    [
      {:ets_owner, "~> 1.0"},
      {:ex2ms, "~> 1.0"},
      {:shorter_maps, "~> 1.0"},
    ]
  end
end
