defmodule Memkash.MixProject do
  use Mix.Project

  def project() do
    [
      app: :memkash,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  defp description() do
    "Memcached Client Library for Elixir"
  end

  defp package() do
    [
      maintainers: ["kdxu"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/kdxu/memkash"}
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :connection]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:connection, "~> 1.0.4"},
      {:poolboy, "~> 1.5.1"},
      {:env, "~> 0.2.0"},
      {:ex_doc, "~> 0.18.3", only: [:dev], runtime: false},
    ]
  end
end
