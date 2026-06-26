defmodule KiwiCodec.Wire.VarFloat do
  @moduledoc """
  Kiwi variable-length 32-bit float wire encoding.

  Kiwi stores IEEE-754 single-precision floats with the exponent byte rotated to
  the front so common small values can use a compact one-byte zero encoding.
  """

  import Bitwise

  @uint32_mask 0xFFFF_FFFF

  @spec encode(float() | integer() | :infinity | :negative_infinity | :nan) :: binary()
  def encode(:infinity), do: encode_bits(<<0, 0, 128, 127>>)
  def encode(:negative_infinity), do: encode_bits(<<0, 0, 128, 255>>)
  def encode(:nan), do: encode_bits(<<0, 0, 192, 127>>)

  def encode(value) when is_number(value) do
    encode_bits(<<value::float-32-little>>)
  end

  defp encode_bits(<<raw::32-little>>) do
    bits = (raw >>> 23 ||| raw <<< 9) &&& @uint32_mask

    if (bits &&& 0xFF) == 0 do
      <<0>>
    else
      <<bits::32-little>>
    end
  end

  @type value :: float() | :infinity | :negative_infinity | :nan

  @spec decode(binary()) :: {value(), binary()}
  def decode(<<0, rest::binary>>), do: {0.0, rest}

  def decode(<<bits::32-little, rest::binary>>) do
    raw = (bits <<< 23 ||| bits >>> 9) &&& @uint32_mask

    value =
      case raw do
        0x7F80_0000 -> :infinity
        0xFF80_0000 -> :negative_infinity
        0x7FC0_0000 -> :nan
        _ -> decode_float_bits(raw)
      end

    {value, rest}
  end

  def decode(_binary) do
    raise KiwiCodec.DecodeError, message: "cannot decode varfloat"
  end

  defp decode_float_bits(raw) do
    <<value::float-32-little>> = <<raw::32-little>>
    value
  end
end
