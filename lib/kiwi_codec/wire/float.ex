defmodule KiwiCodec.Wire.Float do
  @moduledoc false

  import Bitwise

  @uint32_mask 0xFFFF_FFFF

  @spec encode_varfloat(float() | integer() | :infinity | :negative_infinity | :nan) :: binary()
  def encode_varfloat(:infinity), do: encode_varfloat_bits(<<0, 0, 128, 127>>)
  def encode_varfloat(:negative_infinity), do: encode_varfloat_bits(<<0, 0, 128, 255>>)
  def encode_varfloat(:nan), do: encode_varfloat_bits(<<0, 0, 192, 127>>)

  def encode_varfloat(value) when is_number(value) do
    encode_varfloat_bits(<<value::float-32-little>>)
  end

  defp encode_varfloat_bits(<<raw::32-little>>) do
    bits = (raw >>> 23 ||| raw <<< 9) &&& @uint32_mask

    if (bits &&& 0xFF) == 0 do
      <<0>>
    else
      <<bits::32-little>>
    end
  end

  @spec decode_varfloat(binary()) :: {float(), binary()}
  def decode_varfloat(<<0, rest::binary>>), do: {0.0, rest}

  def decode_varfloat(<<bits::32-little, rest::binary>>) do
    raw = (bits <<< 23 ||| bits >>> 9) &&& @uint32_mask
    {decode_float_bits(<<raw::32-little>>), rest}
  end

  def decode_varfloat(_binary) do
    raise KiwiCodec.DecodeError, message: "cannot decode varfloat"
  end

  defp decode_float_bits(<<0, 0, 128, 127>>), do: :infinity
  defp decode_float_bits(<<0, 0, 128, 255>>), do: :negative_infinity
  defp decode_float_bits(<<0, 0, 192, 127>>), do: :nan

  defp decode_float_bits(bits) do
    <<value::float-32-little>> = bits
    value
  end
end
