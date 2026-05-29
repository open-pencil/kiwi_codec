defmodule KiwiCodec.Wire do
  @moduledoc false

  alias KiwiCodec.Wire.{Float, Varint}

  @type primitive_type :: :bool | :byte | :float | :int | :int64 | :string | :uint | :uint64

  @spec encode(primitive_type(), term()) :: iodata()
  def encode(:bool, true), do: <<1>>
  def encode(:bool, false), do: <<0>>
  def encode(:byte, value) when is_integer(value) and value in 0..255, do: <<value>>

  def encode(:float, value)
      when is_number(value) or value in [:infinity, :negative_infinity, :nan],
      do: Float.encode_varfloat(value)

  def encode(:int, value), do: Varint.encode_int(value)
  def encode(:int64, value), do: Varint.encode_int64(value)
  def encode(:string, value) when is_binary(value), do: [value, 0]
  def encode(:uint, value), do: Varint.encode_uint(value)
  def encode(:uint64, value), do: Varint.encode_uint64(value)

  def encode(type, value) do
    raise KiwiCodec.EncodeError, message: "invalid #{inspect(value)} for type #{inspect(type)}"
  end

  @spec encode_byte_array(binary()) :: iodata()
  def encode_byte_array(value) when is_binary(value) do
    [Varint.encode_uint(byte_size(value)), value]
  end

  @spec decode(primitive_type(), binary()) :: {term(), binary()}
  def decode(:bool, <<value, rest::binary>>), do: {value != 0, rest}
  def decode(:byte, <<value, rest::binary>>), do: {value, rest}
  def decode(:float, binary), do: Float.decode_varfloat(binary)
  def decode(:int, binary), do: Varint.decode_int(binary)
  def decode(:int64, binary), do: Varint.decode_int64(binary)
  def decode(:string, binary), do: decode_string(binary)
  def decode(:uint, binary), do: Varint.decode_uint(binary)
  def decode(:uint64, binary), do: Varint.decode_uint64(binary)

  def decode(type, _binary) do
    raise KiwiCodec.DecodeError, message: "cannot decode type #{inspect(type)}"
  end

  @spec decode_byte_array(binary()) :: {binary(), binary()}
  def decode_byte_array(binary) do
    {length, rest} = Varint.decode_uint(binary)

    case rest do
      <<value::binary-size(length), tail::binary>> -> {value, tail}
      _ -> raise KiwiCodec.DecodeError, message: "cannot decode byte array"
    end
  end

  defp decode_string(binary) do
    case :binary.match(binary, <<0>>) do
      {index, 1} ->
        <<value::binary-size(index), 0, rest::binary>> = binary

        if String.valid?(value) do
          {value, rest}
        else
          raise KiwiCodec.DecodeError, message: "invalid UTF-8 string"
        end

      :nomatch ->
        raise KiwiCodec.DecodeError, message: "unterminated string"
    end
  end
end
