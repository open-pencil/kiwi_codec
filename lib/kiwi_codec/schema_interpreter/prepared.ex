defmodule KiwiCodec.SchemaInterpreter.Prepared do
  @moduledoc """
  Indexed Kiwi schema for repeated runtime interpretation.

  Prepared schemas preserve the parsed schema definitions while adding constant-
  time definition, message-field, and enum-variant lookup tables. Build one with
  `KiwiCodec.SchemaInterpreter.prepare/1` and reuse it across encode/decode calls.
  """

  alias KiwiCodec.Schema
  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias KiwiCodec.Schema.Message

  @enforce_keys [
    :schema,
    :definitions,
    :message_fields_by_id,
    :enum_names_by_value,
    :enum_values_by_name
  ]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{
            schema: Schema.t(),
            definitions: %{String.t() => Schema.definition()},
            message_fields_by_id: %{String.t() => %{pos_integer() => Schema.Field.t()}},
            enum_names_by_value: %{String.t() => %{integer() => String.t()}},
            enum_values_by_name: %{String.t() => %{String.t() => integer()}}
          }

  @doc false
  @spec new(Schema.t()) :: t()
  def new(%Schema{} = schema) do
    %__MODULE__{
      schema: schema,
      definitions: Map.new(schema.definitions, &{&1.name, &1}),
      message_fields_by_id: indexes(schema.definitions, Message, :fields, :id),
      enum_names_by_value: indexes(schema.definitions, SchemaEnum, :variants, :value, :name),
      enum_values_by_name: indexes(schema.definitions, SchemaEnum, :variants, :name, :value)
    }
  end

  @doc false
  def definition(%__MODULE__{definitions: definitions}, name), do: Map.get(definitions, name)

  @doc false
  def message_field(%__MODULE__{message_fields_by_id: indexes}, definition_name, id) do
    indexes |> Map.get(definition_name, %{}) |> Map.get(id)
  end

  @doc false
  def enum_name(%__MODULE__{enum_names_by_value: indexes}, definition_name, value) do
    indexes |> Map.get(definition_name, %{}) |> Map.get(value)
  end

  @doc false
  def enum_value(%__MODULE__{enum_values_by_name: indexes}, definition_name, name) do
    indexes |> Map.get(definition_name, %{}) |> Map.get(name)
  end

  defp indexes(definitions, module, members_key, key_field, value_field \\ nil) do
    definitions
    |> Enum.flat_map(fn
      %{__struct__: ^module, name: name} = definition ->
        members = Map.fetch!(definition, members_key)

        index = Map.new(members, &index_entry(&1, key_field, value_field))
        [{name, index}]

      _definition ->
        []
    end)
    |> Map.new()
  end

  defp index_entry(member, key_field, nil), do: {Map.fetch!(member, key_field), member}

  defp index_entry(member, key_field, value_field) do
    {Map.fetch!(member, key_field), Map.fetch!(member, value_field)}
  end
end
