if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Skip.Helpers do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [KiwiCodec.RustlerGenerator.UnknownFields]

    @moduledoc """
    Skip decoders: they read past a value without building a term, for callers projecting a
    few fields out of a large message.

    `kiwi_skip_struct_decoder!` defines a struct's skip decoder. A message's comes from
    `KiwiCodec.RustlerGenerator.Skip.Messages`, or with sparse decoders from
    `KiwiCodec.RustlerGenerator.Sparse.SkipMessages`. An enum is skipped as the `uint` it is
    on the wire.
    """

    require KiwiCodec.RustlerGenerator.Primitive, as: Primitive

    alias RustQ.Type, as: R

    @typedoc "The Rust `KiwiSkipFn`: skips one value of a type."
    @type kiwi_skip_fn :: R.raw(:"fn(&mut Decoder<'_>) -> NifResult<()>")

    @typedoc "The Rust `KiwiSkipKind`: how a field's value is skipped, once, repeated, or as bytes."
    @type kiwi_skip_kind ::
            R.enum(one: [kiwi_skip_fn()], repeated: [kiwi_skip_fn()], bytes: [])

    @typedoc "The Rust `KiwiSkipField`: a message field id and how to skip its value."
    @type kiwi_skip_field :: %{
            required(:id) => R.u32(),
            required(:kind) => kiwi_skip_kind()
          }

    defrustmacro kiwi_skip_struct_decoder(
                   fn: name(:ident),
                   fields:
                     repeat do
                       field_repeated(:literal)
                       field_bytes(:literal)
                       field_skip(:ident)
                     end
                 ) do
      @spec name(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) :: R.nif_result(R.unit())
      defrust name(decoder) do
        kiwi_skip_struct_fields(
          decoder,
          array([
            repeat fields do
              kiwi_skip_descriptor_kind(field_repeated, field_bytes, field_skip)
            end
          ])
        )
      end
    end

    Primitive.defrust_skippers()

    @spec kiwi_skip_descriptor_kind(R.bool(), R.bool(), kiwi_skip_fn()) :: kiwi_skip_kind()
    defrust kiwi_skip_descriptor_kind(repeated, bytes, skip) do
      cond do
        bytes -> enum_variant(KiwiSkipKind, :bytes)
        repeated -> enum_variant(KiwiSkipKind, :repeated, skip)
        true -> enum_variant(KiwiSkipKind, :one, skip)
      end
    end

    @spec kiwi_skip_repeated(R.mut_ref(R.path(:Decoder, R.lifetime(:_))), kiwi_skip_fn()) ::
            R.nif_result(R.unit())
    defrust kiwi_skip_repeated(decoder, item) do
      decoder.read_repeated(fn decoder -> item(decoder) end)
      :ok
    end

    @spec kiwi_skip_kind(R.mut_ref(R.path(:Decoder, R.lifetime(:_))), R.ref(kiwi_skip_kind())) ::
            R.nif_result(R.unit())
    defrust kiwi_skip_kind(decoder, kind) do
      case kind do
        enum_variant(KiwiSkipKind, :one, skip) -> skip(decoder)
        enum_variant(KiwiSkipKind, :repeated, skip) -> kiwi_skip_repeated(decoder, deref(skip))
        enum_variant(KiwiSkipKind, :bytes) -> kiwi_skip_bytes_value(decoder)
      end
    end

    @spec kiwi_skip_struct_fields(
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.slice(kiwi_skip_kind())
          ) :: R.nif_result(R.unit())
    defrust kiwi_skip_struct_fields(decoder, fields) do
      for kind <- fields do
        kiwi_skip_kind(decoder, kind)
      end

      :ok
    end

    # A message's fields end at field id 0, in any order and each at most once.
    @spec kiwi_skip_message_fields(
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.str(),
            R.slice(kiwi_skip_field())
          ) :: R.nif_result(R.unit())
    defrust kiwi_skip_message_fields(decoder, definition_name, fields) do
      field_id = decoder.read_var_uint()

      if field_id == 0 do
        :ok
      else
        case fields.binary_search_by_key(field_id, fn field -> field.id end) do
          {:ok, index} -> kiwi_skip_kind(decoder, index(fields, index).kind)
          {:error, _index} -> kiwi_unknown_field(decoder, definition_name, field_id)
        end

        kiwi_skip_message_fields(decoder, definition_name, fields)
      end
    end
  end
end
