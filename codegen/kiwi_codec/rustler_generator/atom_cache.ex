if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.AtomCache do
    use RustQ.Meta, provides: ["templates/atom_cache.rs"]

    @moduledoc """
    Interns the atoms generated sparse decoders put in every map: the module name, the
    `__kiwi_module__` key, and each field name.

    Creating an atom from its name takes the VM's atom table lock and hashes the text, which
    dominated decoding large files. `kiwi_atom(env, name)` does it once per name and scheduler
    thread.
    """

    @doc "Returns the Rust items defining `kiwi_atom`."
    @spec fragments() :: [RustQ.Rust.Fragment.t()]
    def fragments, do: __rustq_items__()
  end
end
