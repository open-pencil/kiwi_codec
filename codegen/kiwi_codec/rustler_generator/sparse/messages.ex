if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Sparse.Messages do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [KiwiCodec.RustlerGenerator.Sparse.Helpers]

    @moduledoc """
    `kiwi_sparse_message_decoder!`, which defines a message's sparse decoder from one row per
    field, sorted by id; see `KiwiCodec.RustlerGenerator.Sparse.Helpers`.
    """

    alias RustQ.Type, as: R

    defrustmacro kiwi_sparse_message_decoder(
                   fn: name(:ident),
                   module: module_name(:literal),
                   definition: definition_name(:literal),
                   fields:
                     repeat do
                       field_id(:literal)
                       field_name(:literal)
                       field_repeated(:literal)
                       field_decode(:ident)
                     end
                 ) do
      @spec name(R.path(:Env, R.lifetime(:a)), R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
              R.nif_result(term())
      defrust name(env, decoder) do
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
    end
  end
end
