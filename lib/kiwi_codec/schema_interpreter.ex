defmodule KiwiCodec.SchemaInterpreter do
  @moduledoc """
  Interpreter for parsed Kiwi schemas without generated modules.

  Prefer generated modules for application code. This interpreter is useful for
  tooling, inspection, and compatibility tests where schemas are loaded at runtime.
  For repeated calls, prepare the parsed schema once with `prepare/1` to replace
  linear definition, message-field, and enum lookups with indexed lookups.
  """

  alias KiwiCodec.Schema
  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias KiwiCodec.Schema.{Field, Message, Struct}
  alias KiwiCodec.SchemaInterpreter.Prepared
  alias KiwiCodec.Wire
  alias KiwiCodec.Wire.Varint

  @type schema :: Schema.t() | Prepared.t()

  @doc """
  Builds reusable lookup indexes for repeated runtime interpretation.
  """
  @spec prepare(Schema.t()) :: Prepared.t()
  def prepare(%Schema{} = schema), do: Prepared.new(schema)

  @spec decode(schema(), String.t(), binary()) :: map() | String.t() | integer()
  def decode(schema, definition_name, binary)
      when is_struct(schema, Schema) or is_struct(schema, Prepared) do
    {value, rest} = decode_definition(schema, definition!(schema, definition_name), binary)

    if rest == "" do
      value
    else
      raise KiwiCodec.DecodeError, message: "unexpected trailing bytes"
    end
  end

  @spec encode(schema(), String.t(), map()) :: binary()
  def encode(schema, definition_name, value)
      when is_struct(schema, Schema) or is_struct(schema, Prepared) do
    definition = definition!(schema, definition_name)

    schema
    |> encode_definition(definition, value)
    |> IO.iodata_to_binary()
  end

  defp decode_definition(schema, %Message{} = definition, binary) do
    decode_message(schema, definition, binary, %{})
  end

  defp decode_definition(schema, %Struct{} = definition, binary) do
    Enum.reduce(definition.fields, {%{}, binary}, fn field, {acc, rest} ->
      {value, tail} = decode_wire_field(schema, field, rest)
      {Map.put(acc, field.name, value), tail}
    end)
  end

  defp decode_definition(schema, %SchemaEnum{} = definition, binary) do
    {value, rest} = Varint.decode_uint(binary)
    {enum_name(schema, definition, value) || value, rest}
  end

  defp decode_message(schema, definition, binary, acc) do
    {field_id, rest} = Varint.decode_uint(binary)

    case field_id do
      0 ->
        {acc, rest}

      id ->
        field = message_field(schema, definition, id) || raise_unknown_field(definition, id)
        {value, tail} = decode_wire_field(schema, field, rest)
        decode_message(schema, definition, tail, Map.put(acc, field.name, value))
    end
  end

  defp decode_wire_field(_schema, %Field{array?: true, type: "byte"}, binary) do
    Wire.decode_byte_array(binary)
  end

  defp decode_wire_field(schema, %Field{array?: true} = field, binary) do
    {length, rest} = Varint.decode_uint(binary)

    Enum.reduce(1..length//1, {[], rest}, fn _index, {values, tail} ->
      {value, next} = decode_wire_type(schema, field.type, tail)
      {[value | values], next}
    end)
    |> then(fn {values, tail} -> {Enum.reverse(values), tail} end)
  end

  defp decode_wire_field(schema, field, binary), do: decode_wire_type(schema, field.type, binary)

  defp decode_wire_type(schema, type, binary) do
    if KiwiCodec.PrimitiveType.name?(type) do
      Wire.decode(KiwiCodec.PrimitiveType.to_atom!(type), binary)
    else
      decode_definition(schema, definition!(schema, type), binary)
    end
  end

  defp encode_definition(schema, %Message{} = definition, value) when is_map(value) do
    [Enum.map(definition.fields, &encode_message_field(schema, &1, value)), Varint.encode_uint(0)]
  end

  defp encode_definition(schema, %Struct{} = definition, value) when is_map(value) do
    Enum.map(definition.fields, fn field ->
      field_value = fetch_value!(value, field.name)
      encode_wire_field(schema, field, field_value)
    end)
  end

  defp encode_definition(schema, %SchemaEnum{} = definition, value) do
    cond do
      is_integer(value) ->
        Varint.encode_uint(value)

      is_binary(value) ->
        schema
        |> enum_value(definition, value)
        |> case do
          nil -> raise KiwiCodec.EncodeError, message: "invalid enum value #{inspect(value)}"
          enum_value -> Varint.encode_uint(enum_value)
        end

      true ->
        raise KiwiCodec.EncodeError, message: "invalid enum value #{inspect(value)}"
    end
  end

  defp encode_message_field(schema, field, value) do
    case fetch_value(value, field.name) do
      nil ->
        []

      field_value ->
        [Varint.encode_uint(field.id), encode_wire_field(schema, field, field_value)]
    end
  end

  defp encode_wire_field(_schema, %Field{array?: true, type: "byte"}, value)
       when is_binary(value) do
    Wire.encode_byte_array(value)
  end

  defp encode_wire_field(schema, %Field{array?: true} = field, values) when is_list(values) do
    [
      Varint.encode_uint(length(values)),
      Enum.map(values, &encode_wire_type(schema, field.type, &1))
    ]
  end

  defp encode_wire_field(schema, field, value), do: encode_wire_type(schema, field.type, value)

  defp encode_wire_type(schema, type, value) do
    if KiwiCodec.PrimitiveType.name?(type) do
      Wire.encode(KiwiCodec.PrimitiveType.to_atom!(type), value)
    else
      encode_definition(schema, definition!(schema, type), value)
    end
  end

  defp definition!(%Prepared{} = schema, name) do
    Prepared.definition(schema, name) ||
      raise ArgumentError, "unknown definition #{inspect(name)}"
  end

  defp definition!(%Schema{} = schema, name) do
    Schema.definition(schema, name) || raise ArgumentError, "unknown definition #{inspect(name)}"
  end

  defp message_field(%Prepared{} = schema, definition, id) do
    Prepared.message_field(schema, definition.name, id)
  end

  defp message_field(%Schema{}, definition, id), do: Enum.find(definition.fields, &(&1.id == id))

  defp enum_name(%Prepared{} = schema, definition, value) do
    Prepared.enum_name(schema, definition.name, value)
  end

  defp enum_name(%Schema{}, definition, value) do
    case Enum.find(definition.variants, &(&1.value == value)) do
      nil -> nil
      variant -> variant.name
    end
  end

  defp enum_value(%Prepared{} = schema, definition, name) do
    Prepared.enum_value(schema, definition.name, name)
  end

  defp enum_value(%Schema{}, definition, name) do
    case Enum.find(definition.variants, &(&1.name == name)) do
      nil -> nil
      variant -> variant.value
    end
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
