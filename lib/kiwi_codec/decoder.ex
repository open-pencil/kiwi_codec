defmodule KiwiCodec.Decoder do
  @moduledoc """
  Decodes Kiwi wire binaries into generated Kiwi structs.

  This module is used by `KiwiCodec.decode/2`; callers normally interact with
  the public API or generated module `decode/1` functions.
  """

  alias KiwiCodec.Metadata
  alias KiwiCodec.Metadata.Field
  alias KiwiCodec.SchemaInterpreter
  alias KiwiCodec.Wire
  alias KiwiCodec.Wire.Varint

  @spec decode(binary(), module(), keyword()) :: struct()
  def decode(binary, module, opts \\ []) when is_binary(binary) and is_atom(module) do
    schema = opts |> Keyword.get(:schema) |> prepare_schema()
    {value, rest} = decode_from_module(binary, module, schema)

    if rest == "" do
      value
    else
      raise KiwiCodec.DecodeError, message: "unexpected trailing bytes"
    end
  end

  defp prepare_schema(nil), do: nil
  defp prepare_schema(%KiwiCodec.Schema{} = schema), do: SchemaInterpreter.prepare(schema)
  defp prepare_schema(%SchemaInterpreter.Prepared{} = schema), do: schema

  defp decode_from_module(binary, module, schema) do
    {value, rest} =
      case module.__kiwi_metadata__() do
        %Metadata{kind: :message} = metadata ->
          decode_message(binary, struct(module), metadata, schema)

        %Metadata{kind: :struct} = metadata ->
          decode_struct(binary, struct(module), metadata, schema)
      end

    {transform(value, module), rest}
  end

  defp decode_message(binary, struct, %Metadata{fields_by_id: fields_by_id} = metadata, schema) do
    {field_id, rest} = Varint.decode_uint(binary)

    case {field_id, Map.get(fields_by_id, field_id)} do
      {0, _field} ->
        {struct, rest}

      {id, nil} ->
        decode_message(skip_unknown_field(rest, struct, id, schema), struct, metadata, schema)

      {_id, field} ->
        {value, tail} = decode_wire_field(rest, field, struct.__struct__, schema)
        decode_message(tail, Map.put(struct, field.name, value), metadata, schema)
    end
  end

  defp decode_struct(binary, struct, %Metadata{ordered_fields: fields}, schema) do
    decode_struct_fields(fields, struct, binary, struct.__struct__, schema)
  end

  defp decode_struct_fields([], struct, binary, _module, _schema), do: {struct, binary}

  defp decode_struct_fields([field | fields], struct, binary, module, schema) do
    {value, rest} = decode_wire_field(binary, field, module, schema)
    decode_struct_fields(fields, Map.put(struct, field.name, value), rest, module, schema)
  end

  # Generated modules are named after their schema definitions.
  defp skip_unknown_field(_binary, struct, id, nil), do: raise_unknown_field(struct, id)

  defp skip_unknown_field(binary, %module{}, id, schema) do
    definition_name = module |> Module.split() |> List.last()
    SchemaInterpreter.skip_message_field(schema, definition_name, id, binary)
  end

  defp decode_wire_field(binary, %Field{} = field, module, schema) do
    do_decode_wire_field(binary, field, schema)
  rescue
    error in [KiwiCodec.DecodeError, ArgumentError, FunctionClauseError, MatchError] ->
      raise_decode_field_error(module, field, error)
  end

  defp do_decode_wire_field(binary, %Field{repeated?: true, type: :byte}, _schema) do
    Wire.decode_byte_array(binary)
  end

  defp do_decode_wire_field(binary, %Field{repeated?: true} = field, schema) do
    {length, rest} = Varint.decode_uint(binary)
    decode_repeated_wire_type(length, field.type, rest, [], schema)
  end

  defp do_decode_wire_field(binary, %Field{} = field, schema) do
    decode_wire_type(field.type, binary, schema)
  end

  defp decode_repeated_wire_type(0, _type, binary, acc, _schema),
    do: {Enum.reverse(acc), binary}

  defp decode_repeated_wire_type(count, type, binary, acc, schema) do
    {value, rest} = decode_wire_type(type, binary, schema)
    decode_repeated_wire_type(count - 1, type, rest, [value | acc], schema)
  end

  defp decode_wire_type({:enum, module}, binary, _schema) do
    {value, rest} = Varint.decode_uint(binary)
    {module.key(value), rest}
  end

  defp decode_wire_type(type, binary, schema) when is_atom(type) do
    if KiwiCodec.PrimitiveType.atom?(type) do
      Wire.decode(type, binary)
    else
      decode_from_module(binary, type, schema)
    end
  end

  defp transform(message, module) do
    case module.transform_module() do
      nil -> message
      transform_module -> transform_module.decode(message, module)
    end
  end

  defp raise_unknown_field(struct, id) do
    raise KiwiCodec.DecodeError,
      message: "unknown field #{id} while decoding #{inspect(struct.__struct__)}"
  end

  defp raise_decode_field_error(module, field, error) do
    raise KiwiCodec.DecodeError,
      message: "error decoding #{inspect(module)}##{field.name}: #{Exception.message(error)}"
  end
end
