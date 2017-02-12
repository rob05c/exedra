defmodule Exedra.Mixfile do
  use Mix.Project

  def project do
    [app: :exedra,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :ssh],
     mod: {Exedra, []}]
  end

  defp deps do
    []
  end
end
