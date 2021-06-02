defmodule Flub.Mixfile do
  use Mix.Project

  @version "1.1.4"
  @repo_url "https://github.com/meyercm/flub"

  def project do
    [
      app: :flub,
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: hex_package(),
      description: "Sane pub/sub within and across nodes."
    ]
  end

  def application do
    [
      extra_applications: [],
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
      {:ex2ms, "~> 1.6"},
      {:shorter_maps, "~> 2.2"},
      {:gproc, "~> 0.9"},
      {:ex_doc, ">= 0.0.0", only: :dev},
    ]
  end
end
