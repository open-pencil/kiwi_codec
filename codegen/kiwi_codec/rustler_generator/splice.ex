if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Splice do
    @moduledoc """
    Static RustQ splice fragments required by generated Rustler decoders.

    Generated schema code targets compact Rust macros so high-level Elixir
    generators can stay semantic without expanding large repetitive Rust bodies.
    The shared macros and helper functions are authored through RustQ `defrust`,
    `defrustmacro`, and type metadata in the helper modules selected here.
    """

    alias KiwiCodec.RustlerGenerator.AtomCache
    alias KiwiCodec.RustlerGenerator.Decoder
    alias KiwiCodec.RustlerGenerator.Full
    alias KiwiCodec.RustlerGenerator.Skip
    alias KiwiCodec.RustlerGenerator.Sparse
    alias KiwiCodec.RustlerGenerator.UnknownFields
    alias RustQ.Rust.AST
    alias RustQ.Rustler.{Atom, Term}

    @spec rustler_helpers(keyword()) :: [AST.item()]
    def rustler_helpers(opts \\ []) do
      features = Keyword.get(opts, :features, [:full])
      decoder_sources = helper_decoder_sources(opts, features)

      decoder_macros(features, decoder_sources, opts) ++
        UnknownFields.fragments(Keyword.get(opts, :unknown_fields, :error)) ++
        Atom.cached([]) ++
        Term.helpers(
          include: [
            :cached_struct_keys,
            :default_struct_values,
            :make_struct_from_arrays
          ]
        )
    end

    defp helper_decoder_sources(opts, _features) do
      opts |> Keyword.get(:decoder_sources, []) |> Decoder.sources()
    end

    defp decoder_macros(features, decoder_sources, opts) do
      [
        if(:full in features, do: full_decoder_macro_fragments(), else: []),
        if(:skip in features,
          do:
            skip_decoder_fragments(
              decoder_sources,
              shared_sparse_skip?(features, opts),
              :sparse in features
            ),
          else: []
        ),
        if(:sparse in features or :records in features, do: AtomCache.fragments(), else: []),
        if(:sparse in features,
          do:
            sparse_decoder_fragments(decoder_sources, shared_sparse_skip?(features, opts), opts),
          else: []
        )
      ]
      |> List.flatten()
    end

    defp full_decoder_macro_fragments do
      [
        Full.Helpers.fragments([
          :kiwi_enum_decoder,
          :kiwi_struct_decoder,
          :kiwi_message_decoder
        ]),
        []
      ]
      |> List.flatten()
    end

    # Sparse helpers define `kiwi_skip_descriptor_kind` for themselves, so skip decoders bring
    # it only without them. A shared sparse and skip descriptor replaces the skip message macro.
    defp skip_decoder_fragments(decoder_sources, shared?, sparse?) do
      [
        Skip.Helpers.fragments(decoder_sources),
        Skip.ValueHelpers.dispatch_fragments(descriptor_kind?: not sparse?),
        if(shared?, do: [], else: Skip.ValueHelpers.macro_fragments([:kiwi_skip_message_decoder]))
      ]
      |> List.flatten()
    end

    defp shared_sparse_skip?(features, opts) do
      :sparse in features and :skip in features and
        Keyword.get(opts, :sparse_messages, :match) == :descriptor
    end

    defp sparse_decoder_fragments(decoder_sources, shared?, _opts) do
      Sparse.Helpers.fragments(decoder_sources, macros: sparse_helper_macros(shared?))
    end

    defp sparse_helper_macros(true),
      do: [
        :kiwi_sparse_enum_decoder,
        :kiwi_sparse_struct_decoder,
        :kiwi_sparse_skip_message_descriptor_decoder
      ]

    defp sparse_helper_macros(false),
      do: [
        :kiwi_sparse_enum_decoder,
        :kiwi_sparse_struct_decoder,
        :kiwi_sparse_message_descriptor_decoder
      ]
  end
end
