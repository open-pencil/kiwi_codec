defmodule KiwiCodec.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/open-pencil/kiwi_codec"

  def project do
    [
      app: :kiwi_codec,
      version: @version,
      elixir: "~> 1.19",
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      description: "Pure Elixir codec for Kiwi schema binary messages",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix], flags: [:no_opaque]],
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # The Rustler generator under codegen/ compiles only where RustQ, an optional dependency,
  # is available, such as a consumer's development and test builds.
  defp elixirc_paths(:test), do: ["lib", "codegen", "test/support"]
  defp elixirc_paths(_env), do: ["lib", "codegen"]

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer --plt",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end

  defp deps do
    [
      rustq_dep(),
      {:varint, "~> 1.6"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp rustq_dep do
    {:rustq, "~> 1.0.0-rc.14", optional: true, runtime: false}
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ["lib", "codegen", "guides", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE*"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/rustler-generator-architecture.md"
      ],
      groups_for_modules: docs_groups_for_modules(),
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp docs_groups_for_modules do
    [
      Codec: [
        KiwiCodec,
        KiwiCodec.Container,
        KiwiCodec.Decoder,
        KiwiCodec.Encoder,
        KiwiCodec.DecodeError,
        KiwiCodec.EncodeError,
        KiwiCodec.TransformModule,
        KiwiCodec.Inspect
      ],
      Schema: [
        KiwiCodec.Schema,
        KiwiCodec.Schema.Enum,
        KiwiCodec.Schema.EnumVariant,
        KiwiCodec.Schema.Field,
        KiwiCodec.Schema.Message,
        KiwiCodec.Schema.Struct,
        KiwiCodec.Schema.Binary,
        KiwiCodec.Metadata,
        KiwiCodec.Metadata.Field,
        KiwiCodec.SchemaInterpreter,
        KiwiCodec.SchemaInterpreter.Prepared,
        KiwiCodec.PrimitiveType
      ],
      "Wire encoding": [
        KiwiCodec.Wire,
        KiwiCodec.Wire.VarFloat,
        KiwiCodec.Wire.Varint
      ],
      "Elixir generation": [
        KiwiCodec.ModuleGenerator,
        KiwiCodec.ModuleCompiler,
        KiwiCodec.FileGenerator,
        KiwiCodec.DSL,
        KiwiCodec.GeneratedModule.Metadata,
        KiwiCodec.GeneratedModule.Shape,
        KiwiCodec.GeneratedModule.TypeSpec
      ],
      "Rustler generation": [
        KiwiCodec.RustlerGenerator,
        KiwiCodec.RustlerGenerator.Decoder,
        KiwiCodec.RustlerGenerator.Records,
        KiwiCodec.RustlerGenerator.UnknownFields,
        KiwiCodec.RustlerGenerator.Skip,
        KiwiCodec.RustlerGenerator.Skip.Kind,
        KiwiCodec.RustlerGenerator.Sparse
      ],
      "Rustler generation internals": [
        KiwiCodec.RustlerGenerator.AtomCache,
        KiwiCodec.RustlerGenerator.DecoderMacro,
        KiwiCodec.RustlerGenerator.Definition,
        KiwiCodec.RustlerGenerator.Entrypoint,
        KiwiCodec.RustlerGenerator.Full.Helpers,
        KiwiCodec.RustlerGenerator.Name,
        KiwiCodec.RustlerGenerator.RustExpr,
        KiwiCodec.RustlerGenerator.Selection,
        KiwiCodec.RustlerGenerator.Skip.Descriptor,
        KiwiCodec.RustlerGenerator.Skip.Helpers,
        KiwiCodec.RustlerGenerator.Skip.ValueHelpers,
        KiwiCodec.RustlerGenerator.Sparse.Helpers,
        KiwiCodec.RustlerGenerator.Splice
      ],
      "Schema internals": [
        KiwiCodec.Schema.Binary.TypeIndex,
        KiwiCodec.Schema.Parser,
        KiwiCodec.Schema.Token,
        KiwiCodec.Schema.Tokenizer,
        KiwiCodec.Schema.Validator
      ]
    ]
  end
end
