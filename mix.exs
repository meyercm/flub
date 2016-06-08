defmodule Flub.Mixfile do
  use Mix.Project

  def project do
    [app: :flub,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :ets_owner],
     mod: {Flub.App, []}]
  end

  defp deps do
    [
      {:ets_owner, "~> 1.0"},
      {:ex2ms, "~> 1.0"},
      {:shorter_maps, github: "meyercm/shorter_maps"},
    ]
  end
end
