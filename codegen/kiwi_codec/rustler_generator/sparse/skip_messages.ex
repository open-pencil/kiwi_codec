if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Sparse.SkipMessages do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [
        KiwiCodec.RustlerGenerator.Sparse.Helpers,
        KiwiCodec.RustlerGenerator.Skip.Helpers
      ]

    @moduledoc """
    `kiwi_sparse_skip_message_decoder!`, which defines both a message's sparse decoder and its
    skip decoder from one row per field, sorted by id, when both are generated; see
    `KiwiCodec.RustlerGenerator.Sparse.Helpers` and `KiwiCodec.RustlerGenerator.Skip.Helpers`.
    """

    alias RustQ.Type, as: R

    defrustmacro kiwi_sparse_skip_message_decoder(
                   sparse_fn: sparse_name(:ident),
                   skip_fn: skip_name(:ident),
                   module: module_name(:literal),
                   definition: definition_name(:literal),
                   fields:
                     repeat do
                       field_id(:literal)
                       field_name(:literal)
                       field_repeated(:literal)
                       field_decode(:ident)
                       field_skip_repeated(:literal)
                       field_skip_bytes(:literal)
                       field_skip(:ident)
                     end
                 ) do
      @spec sparse_name(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust sparse_name(env, decoder) do
        kiwi_sparse_message_fields(
          env,
          decoder,
          module_name,
          definition_name,
          array([
            repeat fields do
              struct_literal(KiwiSparseField,
                id: field_id,
                name: field_name,
                repeated: field_repeated,
                decode: field_decode
              )
            end
          ])
        )
      end

      @spec skip_name(R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) :: R.nif_result(R.unit())
      defrust skip_name(decoder) do
        kiwi_skip_message_fields(
          decoder,
          definition_name,
          array([
            repeat fields do
              struct_literal(KiwiSkipField,
                id: field_id,
                kind: kiwi_skip_descriptor_kind(field_skip_repeated, field_skip_bytes, field_skip)
              )
            end
          ])
        )
      end
    end
  end
end
