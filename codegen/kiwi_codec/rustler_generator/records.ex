if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Records do
    use RustQ.Meta

    @moduledoc """
    Generates native Kiwi records: decoded values Rust code can read, change, and share without
    building Elixir terms, and encode later as the sparse maps generated decoders return.

    The record runtime is schema-independent. The schema only supplies a definition table, read
    by the decoder and encoder, and constants naming each definition, field, and enum value for
    code that works with records:

        kiwi_record_definitions::NODE_CHANGE
        kiwi_records::node_change::FILL_PAINTS
        kiwi_records::node_phase::REMOVED

    RustQ code that works with records names this module through `alias`, and RustQ imports the
    runtime's functions, methods, and types from it:

        alias KiwiCodec.RustlerGenerator.Records

        @spec definition(R.ref(Records.kiwi_record())) :: R.u32()
        defrust definition(record), do: record.definition()

    Decoding uses the `Decoder` methods `KiwiCodec.RustlerGenerator.Decoder` lists for records.
    Unknown message fields go through `kiwi_unknown_field`; see
    `KiwiCodec.RustlerGenerator.UnknownFields`.
    """

    alias KiwiCodec.RustlerGenerator.Name
    alias KiwiCodec.Schema.Enum, as: SchemaEnum
    alias KiwiCodec.Schema.Struct
    alias RustQ.Rust.AST.Builder, as: A
    alias RustQ.Rust.Identifier

    @primitives ~w(bool byte int uint float string int64 uint64)

    @kinds %{SchemaEnum => 0, Struct => 1, KiwiCodec.Schema.Message => 2}

    @doc "Returns the record runtime, definition table, and constants for `definitions`."
    @spec fragments([KiwiCodec.Schema.definition()], String.t()) :: [term()]
    def fragments(definitions, module_prefix) do
      indexes =
        definitions |> Enum.with_index() |> Map.new(fn {def, index} -> {def.name, index} end)

      __rustq_items__() ++
        [definition_table(definitions, indexes, module_prefix), constants(definitions, indexes)]
    end

    defp definition_table(definitions, indexes, module_prefix) do
      A.static(
        :KIWI_RECORD_DEFINITIONS,
        {:ref, {:slice, :KiwiRecordDefinition}},
        A.slice(Enum.map(definitions, &definition(&1, indexes, module_prefix)))
      )
    end

    defp definition(definition, indexes, module_prefix) do
      A.struct_expr(:KiwiRecordDefinition,
        kind: A.lit(Map.fetch!(@kinds, definition.__struct__)),
        name: A.lit(definition.name),
        module: A.lit(Name.module_name(module_prefix, definition.name)),
        fields: A.slice(definition |> fields() |> Enum.map(&field(&1, indexes))),
        variants: A.slice(definition |> variants() |> Enum.map(&variant/1))
      )
    end

    defp field(field, indexes) do
      A.struct_expr(:KiwiRecordField,
        id: A.lit(field.id),
        name: A.lit(Name.field_name(field.name)),
        type_index: A.lit(type_index(field.type, indexes)),
        array: A.lit(field.array?)
      )
    end

    defp variant(variant) do
      A.struct_expr(:KiwiRecordVariant,
        value: A.lit(variant.value),
        name: A.lit(Macro.underscore(variant.name))
      )
    end

    # Primitive types are bitwise-negated indexes, definitions their table index.
    defp type_index(type, indexes) do
      case Enum.find_index(@primitives, &(&1 == type)) do
        nil -> Map.fetch!(indexes, type)
        primitive -> Bitwise.bnot(primitive)
      end
    end

    # Struct fields keep wire order, which their ids follow; message fields sort by id.
    defp fields(%Struct{fields: fields}), do: fields
    defp fields(%{fields: fields}), do: Enum.sort_by(fields, & &1.id)
    defp fields(_enum), do: []

    defp variants(%SchemaEnum{variants: variants}), do: Enum.sort_by(variants, & &1.value)
    defp variants(_definition), do: []

    # Definition indexes live apart from field and enum constants, which take any schema name.
    defp constants(definitions, indexes) do
      [
        A.module(
          :kiwi_record_definitions,
          Enum.map(definitions, fn definition ->
            name = definition.name |> Name.rust_identifier() |> String.upcase()
            A.const(name, :u32, A.lit(Map.fetch!(indexes, definition.name)), vis: :pub)
          end),
          vis: :pub
        ),
        A.module(
          :kiwi_records,
          Enum.map(definitions, fn definition ->
            A.module(
              module_identifier(definition.name),
              Enum.map(fields(definition), &field_constant/1) ++
                Enum.map(variants(definition), &variant_constant/1),
              vis: :pub
            )
          end),
          vis: :pub
        )
      ]
    end

    defp field_constant(field) do
      name = field.name |> Name.rust_identifier() |> String.upcase()
      A.const(name, :u32, A.lit(field.id), vis: :pub)
    end

    defp variant_constant(variant) do
      name = variant.name |> Name.rust_identifier() |> String.upcase()
      A.const(name, :u32, A.lit(variant.value), vis: :pub)
    end

    # A keyword, such as the module for a `Type` definition, renders as a raw identifier.
    defp module_identifier(name), do: name |> Name.rust_identifier() |> Identifier.atom!()
  end
end
