defmodule KiwiCodec do
  @moduledoc """
  Pure Elixir codec for Kiwi schema binary messages.

  Kiwi is a compact schema-driven format with message, struct, enum, and primitive
  encodings that differ from Protocol Buffers. This package is intentionally
  generic; product-specific schemas can live in companion packages.
  """

  defmacro __using__(opts) do
    unless Keyword.has_key?(opts, :kind) do
      raise ArgumentError, "expected :kind option"
    end

    quote location: :keep do
      import KiwiCodec.DSL, only: [field: 3, enum_value: 2]
      Module.register_attribute(__MODULE__, :kiwi_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :kiwi_enum_values, accumulate: true)
      @kiwi_options unquote(opts)
      @before_compile KiwiCodec.DSL

      def transform_module, do: nil
      defoverridable transform_module: 0
    end
  end

  @doc """
  Parses `.kiwi` schema text into a schema AST.
  """
  @spec parse_schema!(String.t()) :: KiwiCodec.Schema.t()
  defdelegate parse_schema!(text), to: KiwiCodec.Schema.Parser, as: :parse!

  @doc """
  Compiles `.kiwi` schema text into generated Elixir modules in memory.

  This is a convenience for tests and tooling. For application code, prefer the
  `mix kiwi.gen` task so generated modules are written to source files.
  """
  @spec compile_schema!(String.t(), keyword()) :: [module()]
  defdelegate compile_schema!(text, opts), to: KiwiCodec.Compiler, as: :compile_string!

  @doc """
  Encodes a Kiwi struct.
  """
  @spec encode(struct()) :: binary()
  def encode(struct) do
    struct
    |> encode_to_iodata()
    |> IO.iodata_to_binary()
  end

  @doc """
  Encodes a Kiwi struct to iodata.
  """
  @spec encode_to_iodata(struct()) :: iodata()
  def encode_to_iodata(%module{} = struct) do
    KiwiCodec.Encoder.encode_to_iodata(struct, module)
  end

  @doc """
  Decodes a binary as the given Kiwi module.
  """
  @spec decode(binary(), module()) :: struct()
  def decode(binary, module) when is_binary(binary) and is_atom(module) do
    KiwiCodec.Decoder.decode(binary, module)
  end
end
