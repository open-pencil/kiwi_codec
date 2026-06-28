defmodule KiwiCodec.RustlerGenerator.RustExpr do
  @moduledoc """
  Shared Rust source-expression helpers for Kiwi Rustler generator modules.

  These helpers keep schema-generic renderer modules focused on decoder shape
  while centralizing primitive decoder expressions and small formatting details.
  """

  @spec primitive(KiwiCodec.PrimitiveType.name()) :: String.t() | nil
  def primitive(type) do
    if KiwiCodec.PrimitiveType.name?(type) do
      ["decoder.", decoder_method_name(type), "(", decoder_args_source(type), ")?"]
      |> IO.iodata_to_binary()
    end
  end

  @spec ident(String.t() | atom()) :: String.t()
  def ident(name) when is_atom(name), do: Atom.to_string(name)

  def ident(name) do
    name
    |> Macro.underscore()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end

  @spec indent(iodata(), non_neg_integer()) :: String.t() | []
  def indent([], _spaces), do: []

  def indent(iodata, spaces) do
    padding = String.duplicate(" ", spaces)

    iodata
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.map_join("\n", &(padding <> &1))
  end

  defp decoder_method_name("bool"), do: "read_bool"
  defp decoder_method_name("byte"), do: "read_byte"
  defp decoder_method_name("string"), do: "read_string"
  defp decoder_method_name("float"), do: "read_var_float"
  defp decoder_method_name(type), do: "read_var_" <> type

  defp decoder_args(type) when type in ["float", "string"], do: [:env]
  defp decoder_args(_type), do: []

  defp decoder_args_source(type) do
    type
    |> decoder_args()
    |> Enum.map_join(", ", &Atom.to_string/1)
  end
end
