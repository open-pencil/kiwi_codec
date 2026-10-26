if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Values do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [KiwiCodec.RustlerGenerator.AtomCache]

    @moduledoc """
    What full and sparse decoders share: reading primitive values and enums as terms, and a
    field's value, once or repeated, with the function decoding its type.

    `kiwi_enum_decoder!` defines an enum's decoder, which decodes a known value as its
    variant's atom and an unknown one as the number.
    """

    require KiwiCodec.RustlerGenerator.Primitive, as: Primitive

    alias RustQ.Type, as: R

    @typedoc "The Rust `KiwiDecodeFn`: decodes one value of a type as a term."
    @type kiwi_decode_fn :: R.raw(:"for<'a> fn(Env<'a>, &mut Decoder<'_>) -> NifResult<Term<'a>>")

    @typedoc "The Rust `KiwiEnumVariant`: an enum value and the atom it decodes as."
    @type kiwi_enum_variant :: %{
            required(:value) => R.u32(),
            required(:name) => R.raw(:"&'static str")
          }

    defrustmacro kiwi_enum_decoder(
                   fn: name(:ident),
                   variants:
                     repeat do
                       variant_value(:literal)
                       variant_name(:literal)
                     end
                 ) do
      @spec name(R.path(:Env, R.lifetime(:a)), R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
              R.nif_result(term())
      defrust name(env, decoder) do
        kiwi_enum_value(
          env,
          decoder,
          array([
            repeat variants do
              struct_literal(KiwiEnumVariant, value: variant_value, name: variant_name)
            end
          ])
        )
      end
    end

    Primitive.defrust_readers()

    @spec kiwi_enum_value(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.slice(kiwi_enum_variant())
          ) :: R.nif_result(term())
    defrust kiwi_enum_value(env, decoder, variants) do
      value = decoder.read_var_uint()

      case variants.binary_search_by_key(value, fn variant -> variant.value end) do
        {:ok, index} -> {:ok, kiwi_atom(env, index(variants, index).name).encode(env)}
        {:error, _index} -> {:ok, value.encode(env)}
      end
    end

    @spec kiwi_field_value(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.bool(),
            kiwi_decode_fn()
          ) :: R.nif_result(term())
    defrust kiwi_field_value(env, decoder, repeated, decode) do
      if repeated do
        {:ok, decoder.read_repeated(fn decoder -> decode(env, decoder) end).encode(env)}
      else
        decode(env, decoder)
      end
    end
  end
end
