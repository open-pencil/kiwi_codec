if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Splice do
    @moduledoc """
    The shared Rust generated decoders call: each feature's helper module, whole, with the
    `kiwi_unknown_field` the `:unknown_fields` mode chooses, and for full decoders the Rustler
    helpers caching their atoms and building their structs.
    """

    alias KiwiCodec.RustlerGenerator.{AtomCache, Full, Skip, Sparse, UnknownFields, Values}
    alias RustQ.Rust.AST
    alias RustQ.Rustler.{Atom, Term}

    @spec rustler_helpers(keyword()) :: [AST.item()]
    def rustler_helpers(opts \\ []) do
      features = Keyword.get(opts, :features, [:full])

      Enum.flat_map(helper_modules(features), & &1.__rustq_items__()) ++
        UnknownFields.fragments(Keyword.get(opts, :unknown_fields, :error)) ++
        Atom.cached([]) ++
        Term.helpers(
          include: [:cached_struct_keys, :default_struct_values, :make_struct_from_arrays]
        )
    end

    defp helper_modules(features) do
      sparse? = :sparse in features
      skip? = :skip in features

      [
        {AtomCache, sparse? or :full in features or :records in features},
        {Values, sparse? or :full in features},
        {Full.Helpers, :full in features},
        {Sparse.Helpers, sparse?},
        {Skip.Helpers, skip?},
        {Sparse.SkipMessages, sparse? and skip?},
        {Sparse.Messages, sparse? and not skip?},
        {Skip.Messages, skip? and not sparse?}
      ]
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
    end
  end
end
