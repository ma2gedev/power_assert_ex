defmodule PowerAssert.MixProject do
  use Mix.Project

  def project do
    [
      app: :power_assert,
      version: "0.2.1",
      elixir: "~> 1.9",
      description: "Power Assert in Elixir. Shows evaluation results each expression.",
      package: [
        maintainers: ["Takayuki Matsubara"],
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => "https://github.com/ma2gedev/power_assert_ex"}
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:ex_spec, ">= 2.0.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
