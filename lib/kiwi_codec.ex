defmodule KiwiCodec do
  @moduledoc """
  Encodes and decodes Kiwi messages as Elixir structs.

  `use KiwiCodec, kind: :message`, `:struct`, or `:enum` defines a module for a
  schema definition with the `KiwiCodec.DSL` macros, and `mix kiwi.gen` or
  `compile_schema!/2` generates such modules from a schema. `encode/1` and
  `decode/3` convert their structs to and from Kiwi binaries.

  Data written with a newer schema decodes when `decode/3` is given that schema:
  fields the modules do not define are skipped. `KiwiCodec.SchemaInterpreter`
  works without modules, for schemas loaded at runtime.
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
  defdelegate compile_schema!(text, opts), to: KiwiCodec.ModuleCompiler, as: :compile_string!

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

  Options:

    * `:schema` - the schema the data was written with, as a `KiwiCodec.Schema`
      or a prepared `KiwiCodec.SchemaInterpreter` schema. Message fields the
      generated modules do not define are skipped using it. Without it they
      raise `KiwiCodec.DecodeError`.
  """
  @spec decode(binary(), module(), keyword()) :: struct()
  def decode(binary, module, opts \\ []) when is_binary(binary) and is_atom(module) do
    KiwiCodec.Decoder.decode(binary, module, opts)
  end
end
