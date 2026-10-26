if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Skip.Messages do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [KiwiCodec.RustlerGenerator.Skip.Helpers]

    @moduledoc """
    `kiwi_skip_message_decoder!`, which defines a message's skip decoder from one row per
    field, sorted by id; see `KiwiCodec.RustlerGenerator.Skip.Helpers`.
    """

    alias RustQ.Type, as: R

    defrustmacro kiwi_skip_message_decoder(
                   fn: name(:ident),
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
          array([
            repeat fields do
              struct_literal(KiwiSkipField,
                id: field_id,
                kind: kiwi_skip_descriptor_kind(field_repeated, field_bytes, field_skip)
              )
            end
          ])
        )
      end
    end
  end
end
