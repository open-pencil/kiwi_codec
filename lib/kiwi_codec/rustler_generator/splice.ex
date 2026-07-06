defmodule KiwiCodec.RustlerGenerator.Splice do
  @moduledoc """
  Static RustQ splice fragments required by generated Rustler decoders.

  Generated schema code targets compact Rust macros so high-level Elixir
  generators can stay semantic without expanding large repetitive Rust bodies.
  The shared macros and helper functions are authored through RustQ `defrust`,
  `defrustmacro`, and type metadata in the helper modules selected here.
  """

  alias KiwiCodec.RustlerGenerator.FullDecoderHelpers
  alias KiwiCodec.RustlerGenerator.SkipHelpers
  alias KiwiCodec.RustlerGenerator.SkipValueHelpers
  alias KiwiCodec.RustlerGenerator.SparseHelpers

  @spec rustler_helpers(keyword()) :: [RustQ.Rust.Fragment.t()]
  def rustler_helpers(opts \\ []) do
    features = Keyword.get(opts, :features, [:full])
    decoder_sources = helper_decoder_sources(opts, features)

    decoder_macros(features, decoder_sources, opts) ++
      RustQ.Rustler.cached_atoms([]) ++
      RustQ.Rustler.term_helpers(
        include: [
          :cached_struct_keys,
          :default_struct_values,
          :make_struct_from_nif_term_arrays
        ]
      )
  end

  defp helper_decoder_sources(opts, features) do
    if Enum.any?(features, &(&1 in [:skip, :sparse])) do
      Keyword.get(opts, :decoder_sources, [])
    else
      []
    end
  end

  defp decoder_macros(features, decoder_sources, opts) do
    [
      if(:full in features, do: full_decoder_macro_fragments(), else: []),
      if(:skip in features,
        do: skip_decoder_fragments(decoder_sources, shared_sparse_skip?(features, opts)),
        else: []
      ),
      if(:sparse in features,
        do: sparse_decoder_fragments(decoder_sources, shared_sparse_skip?(features, opts), opts),
        else: []
      )
    ]
    |> List.flatten()
  end

  defp full_decoder_macro_fragments do
    [
      FullDecoderHelpers.fragments([
        :kiwi_enum_decoder,
        :kiwi_struct_decoder,
        :kiwi_message_decoder
      ]),
      []
    ]
    |> List.flatten()
  end

  defp skip_decoder_fragments([], _shared?), do: skip_decoder_helpers()

  defp skip_decoder_fragments(decoder_sources, shared?) do
    [
      SkipHelpers.fragments(decoder_sources),
      skip_decoder_dispatch(
        message_fields?: false,
        struct_fields?: false,
        raw_struct_macro?: false,
        raw_message_macro?: not shared?
      )
    ]
    |> List.flatten()
  end

  defp skip_decoder_helpers do
    [SkipValueHelpers.fragments(), SkipValueHelpers.macro_fragments()]
    |> List.flatten()
  end

  defp skip_decoder_dispatch(opts) do
    raw_struct_macro? = Keyword.fetch!(opts, :raw_struct_macro?)
    raw_message_macro? = Keyword.fetch!(opts, :raw_message_macro?)

    [
      SkipValueHelpers.dispatch_fragments(),
      skip_decoder_macros(raw_struct_macro?, raw_message_macro?)
    ]
    |> List.flatten()
  end

  defp skip_decoder_macros(raw_struct_macro?, raw_message_macro?) do
    raw_macros =
      [
        if(raw_struct_macro?, do: :kiwi_skip_struct_decoder, else: nil),
        if(raw_message_macro?, do: :kiwi_skip_message_decoder, else: nil)
      ]
      |> Enum.reject(&is_nil/1)
      |> then(&SkipValueHelpers.macro_fragments/1)

    if raw_struct_macro? or raw_message_macro? do
      raw_macros
    else
      []
    end
  end

  defp shared_sparse_skip?(features, opts) do
    :sparse in features and :skip in features and
      Keyword.get(opts, :sparse_messages, :match) == :descriptor
  end

  defp sparse_decoder_fragments(decoder_sources, shared?, opts)

  defp sparse_decoder_fragments([], _shared?, _opts) do
    SparseHelpers.fragments([], macros: sparse_helper_macros(false))
  end

  defp sparse_decoder_fragments(decoder_sources, shared?, _opts) do
    SparseHelpers.fragments(decoder_sources, macros: sparse_helper_macros(shared?))
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
