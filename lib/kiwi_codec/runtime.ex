defmodule KiwiCodec.Runtime do
  @moduledoc """
  Interpreter for parsed Kiwi schemas without generated modules.

  Prefer generated modules for application code. This runtime is useful for
  tooling, inspection, and compatibility tests where schemas are loaded at runtime.
  """

  alias KiwiCodec.Schema
  alias KiwiCodec.Schema.{Definition, Field}
  alias KiwiCodec.Wire
  alias KiwiCodec.Wire.Varint

  @primitive_types ~w(bool byte float int int64 string uint uint64)

  @spec decode(Schema.t(), String.t(), binary()) :: map() | String.t() | integer()
  def decode(%Schema{} = schema, definition_name, binary) do
    {value, rest} = decode_value(schema, definition!(schema, definition_name), binary)

    if rest == "" do
      value
    else
      raise KiwiCodec.DecodeError, message: "unexpected trailing bytes"
    end
  end

  @spec encode(Schema.t(), String.t(), map()) :: binary()
  def encode(%Schema{} = schema, definition_name, value) do
    definition = definition!(schema, definition_name)

    schema
    |> encode_value(definition, value)
    |> IO.iodata_to_binary()
  end

  defp decode_value(schema, %Definition{kind: :message} = definition, binary) do
    decode_message(schema, definition, binary, %{})
  end

  defp decode_value(schema, %Definition{kind: :struct} = definition, binary) do
    Enum.reduce(definition.fields, {%{}, binary}, fn field, {acc, rest} ->
      {value, tail} = decode_field(schema, field, rest)
      {Map.put(acc, field.name, value), tail}
    end)
  end

  defp decode_value(_schema, %Definition{kind: :enum} = definition, binary) do
    {value, rest} = Varint.decode_uint(binary)
    field = Enum.find(definition.fields, &(&1.value == value))
    {if(field, do: field.name, else: value), rest}
  end

  defp decode_message(schema, definition, binary, acc) do
    {field_id, rest} = Varint.decode_uint(binary)

    case field_id do
      0 ->
        {acc, rest}

      id ->
        field =
          Enum.find(definition.fields, &(&1.value == id)) || raise_unknown_field(definition, id)

        {value, tail} = decode_field(schema, field, rest)
        decode_message(schema, definition, tail, Map.put(acc, field.name, value))
    end
  end

  defp decode_field(_schema, %Field{array?: true, type: "byte"}, binary) do
    Wire.decode_byte_array(binary)
  end

  defp decode_field(schema, %Field{array?: true} = field, binary) do
    {length, rest} = Varint.decode_uint(binary)

    Enum.reduce(1..length//1, {[], rest}, fn _index, {values, tail} ->
      {value, next} = decode_scalar(schema, field.type, tail)
      {[value | values], next}
    end)
    |> then(fn {values, tail} -> {Enum.reverse(values), tail} end)
  end

  defp decode_field(schema, field, binary), do: decode_scalar(schema, field.type, binary)

  defp decode_scalar(_schema, type, binary) when type in @primitive_types do
    Wire.decode(String.to_existing_atom(type), binary)
  end

  defp decode_scalar(schema, type, binary) do
    decode_value(schema, definition!(schema, type), binary)
  end

  defp encode_value(schema, %Definition{kind: :message} = definition, value) when is_map(value) do
    [Enum.map(definition.fields, &encode_message_field(schema, &1, value)), Varint.encode_uint(0)]
  end

  defp encode_value(schema, %Definition{kind: :struct} = definition, value) when is_map(value) do
    Enum.map(definition.fields, fn field ->
      field_value = fetch_value!(value, field.name)
      encode_field(schema, field, field_value)
    end)
  end

  defp encode_value(_schema, %Definition{kind: :enum} = definition, value) do
    cond do
      is_integer(value) ->
        Varint.encode_uint(value)

      is_binary(value) ->
        definition.fields
        |> Enum.find(&(&1.name == value))
        |> Map.fetch!(:value)
        |> Varint.encode_uint()

      true ->
        raise KiwiCodec.EncodeError, message: "invalid enum value #{inspect(value)}"
    end
  end

  defp encode_message_field(schema, field, value) do
    case fetch_value(value, field.name) do
      nil -> []
      field_value -> [Varint.encode_uint(field.value), encode_field(schema, field, field_value)]
    end
  end

  defp encode_field(_schema, %Field{array?: true, type: "byte"}, value) when is_binary(value) do
    Wire.encode_byte_array(value)
  end

  defp encode_field(schema, %Field{array?: true} = field, values) when is_list(values) do
    [Varint.encode_uint(length(values)), Enum.map(values, &encode_scalar(schema, field.type, &1))]
  end

  defp encode_field(schema, field, value), do: encode_scalar(schema, field.type, value)

  defp encode_scalar(_schema, type, value) when type in @primitive_types do
    Wire.encode(String.to_existing_atom(type), value)
  end

  defp encode_scalar(schema, type, value) do
    encode_value(schema, definition!(schema, type), value)
  end

  defp definition!(schema, name) do
    Schema.definition(schema, name) || raise ArgumentError, "unknown definition #{inspect(name)}"
  end

  defp fetch_value(map, key), do: Map.get(map, key)

  defp fetch_value!(map, key) do
    case fetch_value(map, key) do
      nil -> raise KiwiCodec.EncodeError, message: "missing required field #{inspect(key)}"
      value -> value
    end
  end

  defp raise_unknown_field(definition, id) do
    raise KiwiCodec.DecodeError, message: "unknown field #{id} while decoding #{definition.name}"
  end
end
