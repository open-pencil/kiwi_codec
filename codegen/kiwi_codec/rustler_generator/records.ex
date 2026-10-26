if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Records do
    use RustQ.Meta

    defrustmod(__MODULE__, as: [:kiwi_records])
    defrustmod(Definitions, as: [:kiwi_record_definitions])

    @moduledoc """
    Generates native Kiwi records: decoded values Rust code can read, change, and share without
    building Elixir terms, and encode later as the sparse maps generated decoders return.

    The record runtime is schema-independent. The schema only supplies a definition table, read
    by the decoder and encoder, and constants naming each definition, field, and enum value for
    code that works with records:

        kiwi_record_definitions::NODE_CHANGE
        kiwi_records::NodeChange::FILL_PAINTS
        kiwi_records::NodePhase::REMOVED

    RustQ code that works with records names this module through `alias`, and RustQ imports the
    runtime's functions, methods, and types from it, and the constants' modules:

        alias KiwiCodec.RustlerGenerator.Records

        @spec fill_paints(R.ref(Records.kiwi_record())) :: R.bool()
        defrust fill_paints(record), do: record.has(Records.NodeChange.FILL_PAINTS)

    `Records.Definitions.NODE_CHANGE` names a definition, so a schema definition named
    `Definitions` is reached only through its Rust path.

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

    @doc """
    Returns the record runtime, and the `kiwi_records!` call declaring `definitions`' table and
    constants, one row per definition.
    """
    @spec fragments([KiwiCodec.Schema.definition()], String.t()) :: [term()]
    def fragments(definitions, module_prefix) do
      indexes =
        definitions |> Enum.with_index() |> Map.new(fn {def, index} -> {def.name, index} end)

      rows = Enum.map(definitions, &definition_row(&1, indexes, module_prefix))
      __rustq_items__() ++ [A.macro_item_token_call(:kiwi_records, [rows, "\n"])]
    end

    defp definition_row(definition, indexes, module_prefix) do
      [
        "\n    ",
        tokens([
          definition_type(definition.name),
          constant_name(definition.name),
          A.lit(Map.fetch!(indexes, definition.name)),
          A.lit(Map.fetch!(@kinds, definition.__struct__)),
          A.lit(definition.name),
          A.lit(Name.module_name(module_prefix, definition.name))
        ]),
        " ",
        rows(Enum.map(fields(definition), &field_row(&1, indexes))),
        " ",
        rows(Enum.map(variants(definition), &variant_row/1)),
        ";"
      ]
    end

    defp field_row(field, indexes) do
      tokens([
        constant_name(field.name),
        A.lit(field.id),
        A.lit(Name.field_name(field.name)),
        A.lit(type_index(field.type, indexes)),
        A.lit(field.array?)
      ])
    end

    defp variant_row(variant) do
      tokens([
        constant_name(variant.name),
        A.lit(variant.value),
        A.lit(Macro.underscore(variant.name))
      ])
    end

    defp rows([]), do: "[]"
    defp rows(rows), do: ["[", Enum.map(rows, &["\n        ", &1, ";"]), "\n    ]"]

    defp tokens(tokens), do: Enum.intersperse(tokens, " ")

    defp constant_name(name),
      do: name |> Name.rust_identifier() |> String.upcase() |> Identifier.atom!()

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

    # Constants grouped on a type, as `kiwi_records::NodeChange::GUID`, read as Elixir aliases do:
    # `Records.NodeChange.GUID`. Definition indexes live apart, in `kiwi_record_definitions`,
    # since field and enum constants take any schema name.
    defp definition_type(name),
      do: name |> Name.rust_identifier() |> Macro.camelize() |> Identifier.atom!()
  end
end
