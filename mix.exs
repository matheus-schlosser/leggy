defmodule Leggy.MixProject do
  use Mix.Project

  def project do
    [
      app: :leggy,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Leggy.Application, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 4.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
