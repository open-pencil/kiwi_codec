if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.RustExpr do
    @moduledoc """
    Rust expressions generated decoders read Kiwi values with, built as RustQ AST.

    Each reads one value from the `decoder` in scope, with `env` for values that become terms.
    """

    alias RustQ.Rust.AST
    alias RustQ.Rust.AST.Builder, as: A

    @doc """
    Returns `decoder.read_*(...)?` for a primitive type, or `nil` for a schema definition.
    """
    @spec primitive(String.t()) :: AST.expr() | nil
    def primitive(type) do
      if KiwiCodec.PrimitiveType.name?(type), do: A.try(read(type))
    end

    @doc "Returns the `decoder.read_*(...)` call reading a primitive type, without `?`."
    @spec read(KiwiCodec.PrimitiveType.name()) :: AST.expr()
    def read(type) do
      {method, args} = primitive_decoder(type)
      A.method(:decoder, method, args)
    end

    defp primitive_decoder("bool"), do: {:read_bool, []}
    defp primitive_decoder("byte"), do: {:read_byte, []}
    defp primitive_decoder("string"), do: {:read_string, [:env]}
    defp primitive_decoder("float"), do: {:read_var_float, [:env]}
    defp primitive_decoder("int"), do: {:read_var_int, []}
    defp primitive_decoder("int64"), do: {:read_var_int64, []}
    defp primitive_decoder("uint"), do: {:read_var_uint, []}
    defp primitive_decoder("uint64"), do: {:read_var_uint64, []}
  end
end
