defmodule PowerAssert.Mixfile do
  use Mix.Project

  def project do
    [app: :power_assert,
     version: "0.1.1",
     elixir: "~> 1.0",
     description: "Power Assert in Elixir. Shows evaluation results each expression.",
     package: [
       maintainers: ["Takayuki Matsubara"],
       licenses: ["Apache 2.0"],
       links: %{"GitHub" => "https://github.com/ma2gedev/power_assert_ex"}
     ],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
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
    [ex_spec_dep(Version.compare(System.version, "1.3.0")),
     {:ex_doc, ">= 0.0.0", only: :dev},
     {:shouldi, only: :test}]
  end

  defp ex_spec_dep(:lt) do
    {:ex_spec, "~> 1.0", only: :test}
  end
  defp ex_spec_dep(_) do
    {:ex_spec, ">= 2.0.0", only: :test}
  end
end
