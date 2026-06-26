defmodule KiwiCodec.RustlerGenerator.Splice do
  @moduledoc """
  Static RustQ splice fragments required by generated Rustler decoders.
  """

  @spec rustler_helpers() :: [RustQ.Rust.Fragment.t()]
  def rustler_helpers do
    RustQ.Rustler.cached_atoms([]) ++
      RustQ.Rustler.term_helpers(
        include: [
          :cached_struct_keys,
          :default_struct_values,
          :make_struct_from_nif_term_arrays
        ]
      )
  end
end
