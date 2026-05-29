defmodule KiwiCodec.Schema.Binary do
  @moduledoc """
  Encoder and decoder for Kiwi's compact binary schema format.
  """

  alias KiwiCodec.Schema
  alias KiwiCodec.Schema.{Definition, Field}
  alias KiwiCodec.Wire
  alias KiwiCodec.Wire.Varint

  @types ["bool", "byte", "int", "uint", "float", "string", "int64", "uint64"]
  @kinds [:enum, :struct, :message]
  @kinds_tuple List.to_tuple(@kinds)

  @spec encode(Schema.t()) :: binary()
  def encode(%Schema{definitions: definitions}) do
    definition_index =
      definitions
      |> Enum.with_index()
      |> Map.new(fn {definition, index} -> {definition.name, index} end)

    [
      Varint.encode_uint(length(definitions)),
      Enum.map(definitions, &encode_definition(&1, definition_index))
    ]
    |> IO.iodata_to_binary()
  end

  @spec decode(binary()) :: Schema.t()
  def decode(binary) when is_binary(binary) do
    {count, rest} = Varint.decode_uint(binary)

    {definitions, rest} =
      Enum.reduce(1..count//1, {[], rest}, fn _index, {acc, tail} ->
        {definition, next} = decode_definition(tail)
        {[definition | acc], next}
      end)

    if rest != "", do: raise(KiwiCodec.DecodeError, message: "trailing bytes in binary schema")

    definitions = Enum.reverse(definitions)
    %Schema{definitions: bind_types!(definitions)}
  end

  defp encode_definition(definition, definition_index) do
    kind_index = Enum.find_index(@kinds, &(&1 == definition.kind))

    [
      Wire.encode(:string, definition.name),
      Wire.encode(:byte, kind_index),
      Varint.encode_uint(length(definition.fields)),
      Enum.map(definition.fields, &encode_field(&1, definition_index))
    ]
  end

  defp encode_field(field, definition_index) do
    type_index = Enum.find_index(@types, &(&1 == field.type))

    encoded_type =
      cond do
        is_nil(field.type) -> 0
        is_nil(type_index) -> Map.fetch!(definition_index, field.type)
        true -> Bitwise.bnot(type_index)
      end

    [
      Wire.encode(:string, field.name),
      Varint.encode_int(encoded_type),
      Wire.encode(:byte, if(field.array?, do: 1, else: 0)),
      Varint.encode_uint(field.value)
    ]
  end

  defp decode_definition(binary) do
    {name, rest} = Wire.decode(:string, binary)
    {kind_index, rest} = Wire.decode(:byte, rest)
    {field_count, rest} = Varint.decode_uint(rest)

    {fields, rest} =
      Enum.reduce(1..field_count//1, {[], rest}, fn _index, {acc, tail} ->
        kind = elem(@kinds_tuple, kind_index)
        {field, next} = decode_field(tail, kind)
        {[field | acc], next}
      end)

    {%Definition{name: name, kind: elem(@kinds_tuple, kind_index), fields: Enum.reverse(fields)},
     rest}
  end

  defp decode_field(binary, kind) do
    {name, rest} = Wire.decode(:string, binary)
    {type, rest} = Varint.decode_int(rest)
    {array_flag, rest} = Wire.decode(:byte, rest)
    {value, rest} = Varint.decode_uint(rest)

    {%Field{
       name: name,
       type: if(kind == :enum, do: nil, else: type),
       array?: Bitwise.band(array_flag, 1) == 1,
       value: value
     }, rest}
  end

  defp bind_types!(definitions) do
    Enum.map(definitions, fn definition ->
      fields = Enum.map(definition.fields, &bind_type!(&1, definitions))
      %{definition | fields: fields}
    end)
  end

  defp bind_type!(%Field{type: nil} = field, _definitions), do: field

  defp bind_type!(%Field{type: type} = field, _definitions) when is_integer(type) and type < 0 do
    index = Bitwise.bnot(type)
    %{field | type: Enum.fetch!(@types, index)}
  end

  defp bind_type!(%Field{type: type} = field, definitions) when is_integer(type) do
    %{field | type: definitions |> Enum.fetch!(type) |> Map.fetch!(:name)}
  end
end
