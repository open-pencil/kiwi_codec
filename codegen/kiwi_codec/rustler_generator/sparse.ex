if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Sparse do
    @moduledoc """
    Generates sparse decoders: maps of the fields present, with `__kiwi_module__` naming the
    generated Elixir module; see `KiwiCodec.RustlerGenerator.Sparse.Helpers`.

    With skip decoders generated as well, a message's sparse and skip decoders come from one
    row per field; see `KiwiCodec.RustlerGenerator.Sparse.SkipMessages`.
    """

    alias KiwiCodec.RustlerGenerator.Field
    alias KiwiCodec.RustlerGenerator.Name
    alias KiwiCodec.RustlerGenerator.Sparse.Helpers
    alias KiwiCodec.RustlerGenerator.Sparse.Messages
    alias KiwiCodec.RustlerGenerator.Sparse.SkipMessages
    alias KiwiCodec.RustlerGenerator.Values
    alias KiwiCodec.Schema.Enum, as: SchemaEnum
    alias KiwiCodec.Schema.{Message, Struct}
    alias RustQ.Meta.AST, as: MetaAST

    @doc "The sparse decoders of `definitions`, sharing message rows with skip ones on `skip?`."
    @spec fragments([KiwiCodec.Schema.definition()], String.t(), map(), boolean()) :: [
            RustQ.Rust.Fragment.t()
          ]
    def fragments(definitions, module_prefix, definition_map, skip?) do
      Enum.map(definitions, &decoder(&1, module_prefix, definition_map, skip?))
    end

    defp decoder(%SchemaEnum{name: name, variants: variants}, _prefix, _map, _skip?) do
      MetaAST.macro_call!(Values, :kiwi_enum_decoder,
        fn: Name.sparse_function(name),
        variants:
          variants
          |> Enum.sort_by(& &1.value)
          |> Enum.map(&[variant_value: &1.value, variant_name: Name.field_name(&1.name)])
      )
    end

    defp decoder(%Struct{name: name, fields: fields}, module_prefix, _map, _skip?) do
      MetaAST.macro_call!(Helpers, :kiwi_sparse_struct_decoder,
        fn: Name.sparse_function(name),
        module: Name.module_name(module_prefix, name),
        fields: Enum.map(fields, &Field.sparse_row/1)
      )
    end

    defp decoder(%Message{name: name, fields: fields}, module_prefix, _map, false) do
      MetaAST.macro_call!(Messages, :kiwi_sparse_message_decoder,
        fn: Name.sparse_function(name),
        module: Name.module_name(module_prefix, name),
        definition: name,
        fields: fields |> Enum.sort_by(& &1.id) |> Enum.map(&Field.sparse_row/1)
      )
    end

    defp decoder(%Message{name: name, fields: fields}, module_prefix, definition_map, true) do
      MetaAST.macro_call!(SkipMessages, :kiwi_sparse_skip_message_decoder,
        sparse_fn: Name.sparse_function(name),
        skip_fn: Name.skip_function(name),
        module: Name.module_name(module_prefix, name),
        definition: name,
        fields:
          fields
          |> Enum.sort_by(& &1.id)
          |> Enum.map(&(Field.sparse_row(&1) ++ shared_skip_row(&1, definition_map)))
      )
    end

    defp shared_skip_row(field, definition_map) do
      [field_repeated: repeated?, field_bytes: bytes?, field_skip: skip] =
        Field.skip_row(field, definition_map)

      [field_skip_repeated: repeated?, field_skip_bytes: bytes?, field_skip: skip]
    end
  end
end
