defmodule KiwiCodec.RustlerGenerator.SkipValueHelpers do
  use RustQ.Meta

  @moduledoc """
  RustQ-authored primitive Kiwi skip helpers used by generated Rustler decoders.
  """

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Type, as: R

  @macros [
    :kiwi_skip_struct_decoder,
    :kiwi_skip_message_decoder
  ]

  @dispatch_functions [
    :kiwi_skip_kind
  ]

  @functions [
    :kiwi_skip_bool_value,
    :kiwi_skip_byte_value,
    :kiwi_skip_float_value,
    :kiwi_skip_int_value,
    :kiwi_skip_int64_value,
    :kiwi_skip_string_value,
    :kiwi_skip_uint_value,
    :kiwi_skip_uint64_value,
    :kiwi_skip_bytes_value,
    :kiwi_skip_repeated,
    :kiwi_skip_descriptor_kind,
    :kiwi_skip_kind,
    :kiwi_skip_struct_fields,
    :kiwi_skip_struct_fields_remaining,
    :kiwi_skip_message_fields
  ]

  @type kiwi_skip_fn :: R.raw(:"fn(&mut Decoder<'_>) -> NifResult<()>")

  @type kiwi_skip_kind ::
          R.enum(one: [kiwi_skip_fn()], repeated: [kiwi_skip_fn()], bytes: [])

  @type kiwi_skip_field :: %{
          required(:id) => R.u32(),
          required(:kind) => kiwi_skip_kind()
        }

  @spec fragments() :: [RustQ.Rust.Fragment.t()]
  def fragments do
    __MODULE__.__rustq_type_items__() ++ MetaAST.items(__MODULE__, @functions)
  end

  @spec macro_fragments([atom()]) :: [RustQ.Rust.Fragment.t()]
  def macro_fragments(names \\ @macros) do
    MetaAST.macro_items(__MODULE__, names)
  end

  @spec dispatch_fragments() :: [RustQ.Rust.Fragment.t()]
  def dispatch_fragments do
    MetaAST.items(__MODULE__, @dispatch_functions)
  end

  defrustmacro kiwi_skip_struct_decoder(
                 fn: name(:ident),
                 decoder: decoder(:ident),
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
        ref(
          array([
            repeat fields do
              kiwi_skip_descriptor_kind(field_repeated, field_bytes, field_skip)
            end
          ])
        )
      )
    end
  end

  defrustmacro kiwi_skip_message_decoder(
                 fn: name(:ident),
                 decoder: decoder(:ident),
                 definition: definition_name(:literal),
                 fields:
                   repeat do
                     field_id(:literal)
                     field_repeated(:literal)
                     field_bytes(:literal)
                     field_skip(:ident)
                   end
               ) do
    @spec name(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) :: R.nif_result(R.unit())
    defrust name(decoder) do
      kiwi_skip_message_fields(
        decoder,
        definition_name,
        ref(
          array([
            repeat fields do
              struct_literal(KiwiSkipField,
                id: field_id,
                kind: kiwi_skip_descriptor_kind(field_repeated, field_bytes, field_skip)
              )
            end
          ])
        )
      )
    end
  end

  @spec kiwi_skip_descriptor_kind(R.bool(), R.bool(), kiwi_skip_fn()) :: kiwi_skip_kind()
  defrust kiwi_skip_descriptor_kind(repeated, bytes, skip) do
    if bytes do
      enum_variant(KiwiSkipKind, :bytes)
    else
      if repeated do
        enum_variant(KiwiSkipKind, :repeated, skip)
      else
        enum_variant(KiwiSkipKind, :one, skip)
      end
    end
  end

  @spec kiwi_skip_bool_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_bool_value(decoder) do
    unwrap!(decoder.read_bool())
    :ok
  end

  @spec kiwi_skip_byte_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_byte_value(decoder) do
    unwrap!(decoder.read_byte())
    :ok
  end

  @spec kiwi_skip_float_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_float_value(decoder) do
    unwrap!(decoder.read_var_float_value())
    :ok
  end

  @spec kiwi_skip_int_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) :: R.nif_result(R.unit())
  defrust kiwi_skip_int_value(decoder) do
    unwrap!(decoder.read_var_int())
    :ok
  end

  @spec kiwi_skip_int64_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_int64_value(decoder) do
    unwrap!(decoder.read_var_int64())
    :ok
  end

  @spec kiwi_skip_string_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_string_value(decoder) do
    unwrap!(decoder.skip_string())
    :ok
  end

  @spec kiwi_skip_uint_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_uint_value(decoder) do
    unwrap!(decoder.read_var_uint())
    :ok
  end

  @spec kiwi_skip_uint64_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_uint64_value(decoder) do
    unwrap!(decoder.read_var_uint64())
    :ok
  end

  @spec kiwi_skip_bytes_value(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_bytes_value(decoder) do
    unwrap!(decoder.skip_byte_array())
    :ok
  end

  @spec kiwi_skip_repeated(R.mut_ref(R.path(:Decoder, R.lifetime(:_))), kiwi_skip_fn()) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_repeated(decoder, item) do
    unwrap!(decoder.read_repeated(fn decoder -> item(decoder) end))
    :ok
  end

  @spec kiwi_skip_kind(R.mut_ref(R.path(:Decoder, R.lifetime(:_))), R.ref(kiwi_skip_kind())) ::
          R.nif_result(R.unit())
  defrust kiwi_skip_kind(decoder, kind) do
    case kind do
      enum_variant(KiwiSkipKind, :one, skip) ->
        skip(decoder)

      enum_variant(KiwiSkipKind, :repeated, skip) ->
        kiwi_skip_repeated(decoder, deref(skip))

      enum_variant(KiwiSkipKind, :bytes) ->
        kiwi_skip_bytes_value(decoder)
    end
  end

  @spec kiwi_skip_struct_fields(
          R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
          R.slice(kiwi_skip_kind())
        ) :: R.nif_result(R.unit())
  defrust kiwi_skip_struct_fields(decoder, fields) do
    kiwi_skip_struct_fields_remaining(decoder, fields, 0)
  end

  @spec kiwi_skip_struct_fields_remaining(
          R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
          R.slice(kiwi_skip_kind()),
          R.usize()
        ) :: R.nif_result(R.unit())
  defrust kiwi_skip_struct_fields_remaining(decoder, fields, index) do
    if index == fields.len() do
      :ok
    else
      kind = fields.get(index).unwrap()
      unwrap!(kiwi_skip_kind(decoder, kind))
      kiwi_skip_struct_fields_remaining(decoder, fields, index + 1)
    end
  end

  @spec kiwi_skip_message_fields(
          R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
          R.str(),
          R.slice(kiwi_skip_field())
        ) :: R.nif_result(R.unit())
  defrust kiwi_skip_message_fields(decoder, _definition_name, fields) do
    field_id = unwrap!(decoder.read_var_uint())

    if field_id == 0 do
      :ok
    else
      case fields.binary_search_by_key(ref(field_id), fn field -> field.id end) do
        {:ok, index} ->
          field = fields.get(index).unwrap()
          unwrap!(kiwi_skip_kind(decoder, field.kind))
          kiwi_skip_message_fields(decoder, _definition_name, fields)

        {:error, _index} ->
          {:error, badarg()}
      end
    end
  end
end
