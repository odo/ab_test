defmodule AbTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :ab_test,
      version: "0.1.0",
      elixir: "~> 1.18",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:typed_struct, "~> 0.3"},
    ]
  end
  
  defp description() do
    "ABtest is an Elixir library to run A/B test for product optimization."
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/odo/ab_test"}
    ]
  end
end
