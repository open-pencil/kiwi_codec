if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.AtomCache do
    use RustQ.Meta

    @moduledoc """
    Interns the atoms generated sparse decoders put in every map: the module name, the
    `__kiwi_module__` key, and each field name.

    Creating an atom from its name takes the VM's atom table lock and hashes the text, which
    dominated decoding large files. `kiwi_atom(env, name)` does it once per name and scheduler
    thread.
    """

    alias RustQ.Type, as: R

    @template Path.expand("templates/atom_cache.rs", __DIR__)
    @external_resource @template

    @doc "Returns the Rust items defining `kiwi_atom`."
    @spec fragments() :: [RustQ.Rust.Fragment.t()]
    def fragments do
      [RustQ.Rust.fragment(:item, @template |> File.read!() |> String.trim_trailing())]
    end

    # Typed declaration for callers; the emitted definition is the template.
    @spec kiwi_atom(R.path(:Env, R.lifetime(:_)), R.raw(:"&'static str")) :: R.path(:Atom)
    defrust kiwi_atom(env, name) do
      Atom.from_str(env, name).unwrap()
    end
  end
end
