defmodule SingleFlight.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/yoavgeva/single_flight"

  def project do
    [
      app: :single_flight,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "SingleFlight",
      description: "Deduplicate concurrent function calls by key. Inspired by Go's singleflight.",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "SingleFlight",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
