if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Skip do
    @moduledoc """
    Generates skip decoders, which read past a value without building a term; see
    `KiwiCodec.RustlerGenerator.Skip.Helpers`.

    With sparse decoders generated as well, messages' skip decoders come with their sparse ones;
    see `KiwiCodec.RustlerGenerator.Sparse.SkipMessages`.
    """

    alias KiwiCodec.RustlerGenerator.Field
    alias KiwiCodec.RustlerGenerator.Name
    alias KiwiCodec.RustlerGenerator.Skip.Helpers
    alias KiwiCodec.RustlerGenerator.Skip.Messages
    alias KiwiCodec.Schema.{Message, Struct}
    alias RustQ.Meta.AST, as: MetaAST
    alias RustQ.Rust.AST
    alias RustQ.Rust.AST.Builder, as: A
    alias RustQ.Rust.AST.PatternBuilder, as: P

    @doc "The skip decoders of `definitions`, leaving messages' to the sparse ones on `sparse?`."
    @spec fragments([KiwiCodec.Schema.definition()], map(), boolean()) :: [
            RustQ.Rust.Fragment.t()
          ]
    def fragments(definitions, definition_map, sparse?) do
      Enum.flat_map(definitions, &decoder(&1, definition_map, sparse?))
    end

    @doc "A `match` arm skipping `field`'s value, by its id."
    @spec message_arm(map(), map()) :: AST.Arm.t()
    def message_arm(field, definition_map) do
      %AST.Arm{pattern: P.lit(field.id), body: [A.return_stmt(skip_call(field, definition_map))]}
    end

    defp decoder(%Struct{name: name, fields: fields}, definition_map, _sparse?) do
      [
        MetaAST.macro_call!(Helpers, :kiwi_skip_struct_decoder,
          fn: Name.skip_function(name),
          fields: Enum.map(fields, &Field.skip_row(&1, definition_map))
        )
      ]
    end

    defp decoder(%Message{name: name, fields: fields}, definition_map, false) do
      [
        MetaAST.macro_call!(Messages, :kiwi_skip_message_decoder,
          fn: Name.skip_function(name),
          definition: name,
          fields:
            fields
            |> Enum.sort_by(& &1.id)
            |> Enum.map(&[{:field_id, &1.id} | Field.skip_row(&1, definition_map)])
        )
      ]
    end

    defp decoder(_definition, _definition_map, _sparse?), do: []

    defp skip_call(field, definition_map) do
      case Field.skip(field, definition_map) do
        {true, false, skip} -> A.try(A.call(:kiwi_skip_repeated, [:decoder, A.path(skip)]))
        {_once, _bytes, skip} -> A.try(A.call(skip, [:decoder]))
      end
    end
  end
end
