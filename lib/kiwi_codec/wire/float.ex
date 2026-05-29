defmodule KiwiCodec.Wire.Float do
  @moduledoc false

  import Bitwise

  @uint32_mask 0xFFFF_FFFF

  @spec encode_varfloat(float() | integer()) :: binary()
  def encode_varfloat(value) when is_number(value) do
    <<raw::32-little>> = <<value::float-32-little>>
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
    <<value::float-32-little>> = <<raw::32-little>>
    {value, rest}
  end

  def decode_varfloat(_binary) do
    raise KiwiCodec.DecodeError, message: "cannot decode varfloat"
  end
end
