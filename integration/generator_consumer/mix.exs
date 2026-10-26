defmodule KiwiCodecGeneratorConsumer.MixProject do
  use Mix.Project

  def project do
    [app: :kiwi_codec_generator_consumer, version: "0.1.0", elixir: "~> 1.19", deps: deps()]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:kiwi_codec, path: System.fetch_env!("KIWI_CODEC_PACKAGE_PATH")},
      {:rustq, "~> 1.0.0-rc.19", only: [:dev, :test], runtime: false}
    ]
  end
end
