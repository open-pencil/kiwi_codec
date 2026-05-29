defmodule KiwiCodec.Wire.Varint do
  @moduledoc false

  import Bitwise

  @uint32_max 0xFFFF_FFFF
  @uint64_max 0xFFFF_FFFF_FFFF_FFFF
  @int32_min -0x8000_0000
  @int32_max 0x7FFF_FFFF
  @int64_min -0x8000_0000_0000_0000
  @int64_max 0x7FFF_FFFF_FFFF_FFFF

  @varints [
    {quote(do: <<0::1, x0::7>>), quote(do: decode_segments([x0]))},
    {quote(do: <<1::1, x0::7, 0::1, x1::7>>), quote(do: decode_segments([x0, x1]))},
    {quote(do: <<1::1, x0::7, 1::1, x1::7, 0::1, x2::7>>),
     quote(do: decode_segments([x0, x1, x2]))},
    {quote(do: <<1::1, x0::7, 1::1, x1::7, 1::1, x2::7, 0::1, x3::7>>),
     quote(do: decode_segments([x0, x1, x2, x3]))},
    {quote(do: <<1::1, x0::7, 1::1, x1::7, 1::1, x2::7, 1::1, x3::7, 0::1, x4::7>>),
     quote(do: decode_segments([x0, x1, x2, x3, x4]))},
    {quote(do: <<1::1, x0::7, 1::1, x1::7, 1::1, x2::7, 1::1, x3::7, 1::1, x4::7, 0::1, x5::7>>),
     quote(do: decode_segments([x0, x1, x2, x3, x4, x5]))},
    {quote(
       do:
         <<1::1, x0::7, 1::1, x1::7, 1::1, x2::7, 1::1, x3::7, 1::1, x4::7, 1::1, x5::7, 0::1,
           x6::7>>
     ), quote(do: decode_segments([x0, x1, x2, x3, x4, x5, x6]))},
    {quote(
       do:
         <<1::1, x0::7, 1::1, x1::7, 1::1, x2::7, 1::1, x3::7, 1::1, x4::7, 1::1, x5::7, 1::1,
           x6::7, 0::1, x7::7>>
     ), quote(do: decode_segments([x0, x1, x2, x3, x4, x5, x6, x7]))},
    {quote(
       do:
         <<1::1, x0::7, 1::1, x1::7, 1::1, x2::7, 1::1, x3::7, 1::1, x4::7, 1::1, x5::7, 1::1,
           x6::7, 1::1, x7::7, 0::1, x8::7>>
     ), quote(do: decode_segments([x0, x1, x2, x3, x4, x5, x6, x7, x8]))},
    {quote(
       do:
         <<1::1, x0::7, 1::1, x1::7, 1::1, x2::7, 1::1, x3::7, 1::1, x4::7, 1::1, x5::7, 1::1,
           x6::7, 1::1, x7::7, 1::1, x8::7, 0::1, x9::7>>
     ), quote(do: decode_segments([x0, x1, x2, x3, x4, x5, x6, x7, x8, x9]))}
  ]

  for {pattern, value} <- @varints do
    defp decode_unsigned(<<unquote(pattern), rest::binary>>) do
      {unquote(value), rest}
    end
  end

  defp decode_unsigned(_binary) do
    raise KiwiCodec.DecodeError, message: "cannot decode varint"
  end

  @spec encode_uint(non_neg_integer()) :: iodata()
  def encode_uint(value) when is_integer(value) and value in 0..@uint32_max do
    encode_unsigned(value)
  end

  @spec encode_uint64(non_neg_integer()) :: iodata()
  def encode_uint64(value) when is_integer(value) and value in 0..@uint64_max do
    encode_unsigned(value)
  end

  @spec encode_int(integer()) :: iodata()
  def encode_int(value) when is_integer(value) and value in @int32_min..@int32_max do
    value
    |> zigzag_encode()
    |> encode_unsigned()
  end

  @spec encode_int64(integer()) :: iodata()
  def encode_int64(value) when is_integer(value) and value in @int64_min..@int64_max do
    value
    |> zigzag_encode()
    |> encode_unsigned()
  end

  @spec decode_uint(binary()) :: {non_neg_integer(), binary()}
  def decode_uint(binary) do
    {value, rest} = decode_unsigned(binary)

    if value <= @uint32_max,
      do: {value, rest},
      else: raise(KiwiCodec.DecodeError, message: "uint out of range")
  end

  @spec decode_uint64(binary()) :: {non_neg_integer(), binary()}
  def decode_uint64(binary) do
    {value, rest} = decode_unsigned(binary)

    if value <= @uint64_max,
      do: {value, rest},
      else: raise(KiwiCodec.DecodeError, message: "uint64 out of range")
  end

  @spec decode_int(binary()) :: {integer(), binary()}
  def decode_int(binary) do
    {value, rest} = decode_uint(binary)
    {zigzag_decode(value), rest}
  end

  @spec decode_int64(binary()) :: {integer(), binary()}
  def decode_int64(binary) do
    {value, rest} = decode_uint64(binary)
    {zigzag_decode(value), rest}
  end

  defp encode_unsigned(value) when value <= 0x7F, do: [value]

  defp encode_unsigned(value) do
    [bor(band(value, 0x7F), 0x80) | encode_unsigned(value >>> 7)]
  end

  defp decode_segments(segments) do
    segments
    |> Enum.with_index()
    |> Enum.reduce(0, fn {segment, index}, acc -> acc ||| segment <<< (index * 7) end)
  end

  defp zigzag_encode(value), do: if(value < 0, do: -2 * value - 1, else: 2 * value)

  defp zigzag_decode(value),
    do: if((value &&& 1) == 1, do: -((value + 1) >>> 1), else: value >>> 1)
end
