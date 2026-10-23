defmodule KiwiCodec.RustlerGenerator.Definition do
  @moduledoc """
  Generates Rust items for Kiwi schema definitions.
  """

  alias KiwiCodec.RustlerGenerator.DecoderMacro
  alias KiwiCodec.RustlerGenerator.Name
  alias KiwiCodec.RustlerGenerator.RustExpr
  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias KiwiCodec.Schema.{Message, Struct}
  alias RustQ.Rust
  alias RustQ.Rust.AST.Builder, as: A

  @spec fragments([KiwiCodec.Schema.definition()], String.t(), map()) :: [RustQ.Rust.Fragment.t()]
  def fragments(definitions, module_prefix, definition_map) do
    definitions
    |> Enum.flat_map(&items(&1, module_prefix, definition_map))
    |> Enum.map(&Rust.to_fragment/1)
  end

  defp items(%SchemaEnum{} = definition, _module_prefix, _definition_map) do
    [DecoderMacro.enum_decoder(definition)]
  end

  defp items(%Struct{} = definition, module_prefix, definition_map) do
    [
      atom_static(Name.module_atom_static(definition.name)),
      keys_static(Name.struct_keys_static(definition.name)),
      DecoderMacro.struct_decoder(definition, module_prefix, definition_map, &field_expr/2)
    ]
  end

  defp items(%Message{} = definition, module_prefix, definition_map) do
    [
      atom_static(Name.module_atom_static(definition.name)),
      keys_static(Name.struct_keys_static(definition.name)),
      DecoderMacro.message_decoder(definition, module_prefix, definition_map)
    ]
  end

  defp atom_static(name) do
    A.static(name, "OnceLock<Atom>", A.path_call([:OnceLock, :new]))
  end

  defp keys_static(name) do
    A.static(name, "OnceLock<Vec<Atom>>", A.path_call([:OnceLock, :new]))
  end

  defp field_expr(%{array?: true, type: "byte"}, _definition_map) do
    A.try(A.method(:decoder, :read_byte_array, [:env]))
  end

  defp field_expr(%{array?: true, type: type}, definition_map) do
    read_item = A.closure([:decoder], read(type, definition_map))
    A.try(A.method(:decoder, :read_repeated, [read_item]))
  end

  defp field_expr(%{type: type}, definition_map), do: A.try(read(type, definition_map))

  defp read(type, definition_map) do
    if KiwiCodec.PrimitiveType.name?(type) do
      RustExpr.read(type)
    else
      A.call(Name.decoder_function(Map.fetch!(definition_map, type).name), [:env, :decoder])
    end
  end
end
