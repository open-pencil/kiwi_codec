if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Full do
    @moduledoc """
    Generates full decoders: a struct or message decodes as its generated Elixir struct, an
    enum as its variant's atom; see `KiwiCodec.RustlerGenerator.Full.Helpers`.
    """

    alias KiwiCodec.RustlerGenerator.Field
    alias KiwiCodec.RustlerGenerator.Full.Helpers
    alias KiwiCodec.RustlerGenerator.Name
    alias KiwiCodec.RustlerGenerator.Primitive
    alias KiwiCodec.RustlerGenerator.Values
    alias KiwiCodec.Schema.Enum, as: SchemaEnum
    alias KiwiCodec.Schema.{Message, Struct}
    alias RustQ.Meta.AST, as: MetaAST
    alias RustQ.Rust.AST.Builder, as: A

    @doc "The full decoders of `definitions`, with the statics caching their atoms."
    @spec fragments([KiwiCodec.Schema.definition()], String.t(), map()) :: [
            RustQ.Rust.Fragment.t()
          ]
    def fragments(definitions, module_prefix, definition_map),
      do: Enum.flat_map(definitions, &decoder(&1, module_prefix, definition_map))

    defp decoder(%SchemaEnum{name: name, variants: variants}, _module_prefix, _definition_map) do
      [
        MetaAST.macro_call!(Values, :kiwi_enum_decoder,
          fn: Name.decoder_function(name),
          variants:
            variants
            |> Enum.sort_by(& &1.value)
            |> Enum.map(&[variant_value: &1.value, variant_name: Name.field_name(&1.name)])
        )
      ]
    end

    defp decoder(%Struct{name: name, fields: fields}, module_prefix, definition_map) do
      statics(name) ++
        [
          MetaAST.macro_call!(Helpers, :kiwi_struct_decoder,
            fn: Name.decoder_function(name),
            env: :env,
            decoder: :decoder,
            module_static: Name.module_atom_static(name),
            keys_static: Name.struct_keys_static(name),
            module: Name.module_name(module_prefix, name),
            keys: Enum.map(fields, &[key: Name.field_name(&1.name)]),
            fields: Enum.map(fields, &[field_expr: field_expr(&1, definition_map)])
          )
        ]
    end

    defp decoder(%Message{name: name, fields: fields}, module_prefix, _definition_map) do
      statics(name) ++
        [
          MetaAST.macro_call!(Helpers, :kiwi_message_decoder,
            fn: Name.decoder_function(name),
            fields_fn: Name.message_fields_function(name),
            module_static: Name.module_atom_static(name),
            keys_static: Name.struct_keys_static(name),
            module: Name.module_name(module_prefix, name),
            definition: name,
            keys: Enum.map(fields, &[key: Name.field_name(&1.name)]),
            fields:
              fields
              |> Enum.with_index(1)
              |> Enum.map(fn {field, index} ->
                {repeated?, decode} = Field.read(field, &Name.decoder_function/1)

                [
                  field_id: field.id,
                  field_index: index,
                  field_repeated: repeated?,
                  field_decode: decode
                ]
              end)
          )
        ]
    end

    # A decoded struct's module atom and keys, created once.
    defp statics(name) do
      [
        A.static(Name.module_atom_static(name), once_lock(:Atom), A.path_call([:OnceLock, :new])),
        A.static(
          Name.struct_keys_static(name),
          once_lock(A.type_path(:Vec, generics: [A.type_path(:Atom)])),
          A.path_call([:OnceLock, :new])
        )
      ]
    end

    defp once_lock(type), do: A.type_path(:OnceLock, generics: [A.type(type)])

    # A struct's fields read in wire order, each with `?`; `byte[]` reads as one byte array.
    defp field_expr(%{array?: true, type: "byte"}, _definition_map),
      do: A.try(Primitive.read("bytes"))

    defp field_expr(%{array?: true, type: type}, definition_map),
      do:
        A.try(
          A.method(:decoder, :read_repeated, [A.closure([:decoder], read(type, definition_map))])
        )

    defp field_expr(%{type: type}, definition_map), do: A.try(read(type, definition_map))

    defp read(type, definition_map) do
      if KiwiCodec.PrimitiveType.name?(type),
        do: Primitive.read(type),
        else:
          A.call(Name.decoder_function(Map.fetch!(definition_map, type).name), [:env, :decoder])
    end
  end
end
