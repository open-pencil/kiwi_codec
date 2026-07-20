defmodule KiwiCodecRuntimeConsumer.MixProject do
  use Mix.Project

  def project do
    [app: :kiwi_codec_runtime_consumer, version: "0.1.0", elixir: "~> 1.19", deps: deps()]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [{:kiwi_codec, path: System.fetch_env!("KIWI_CODEC_PACKAGE_PATH")}]
  end
end
