if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Decoder do
    @moduledoc """
    The `Decoder<'a>` generated decoders read Kiwi data with.

    The native crate provides it, imported from `crate::runtime::Decoder` unless the
    generator's `:decoder` option names another path. `decoder.rs`, beside this module, is a
    complete implementation to copy or start from; the tests build every generator feature
    against it. It names the runtime schema type `crate::RuntimeSchema`, which a crate using
    `unknown_fields: :runtime_schema` defines as `pub use KiwiRuntimeSchema as RuntimeSchema;`,
    and any other crate as an empty `pub enum RuntimeSchema {}`.

    Every feature uses `new(&'a [u8])`, `finish(&self) -> NifResult<()>`, and the primitive
    readers, each returning `NifResult`: `read_bool`, `read_byte`, `read_var_uint`,
    `read_var_uint64`, `read_var_int`, `read_var_int64`, `read_var_float_value`,
    `read_var_float(env)`, `read_string(env)`, `read_byte_array(env)`, `skip_string`,
    `skip_byte_array`, and `read_repeated(read)`.

      * Records also need `read_byte_array_value`, `read_string_str`, and `remaining`.
      * `unknown_fields: :runtime_schema` also needs `runtime_schema(&self) ->
        Option<&'a KiwiRuntimeSchema>`, returning `None` to keep the `:error` behavior, and
        `read_string_value`.

    The generator reads the method signatures from `decoder.rs` to know which calls return a
    `NifResult`, so a crate's own `Decoder` keeps them.
    """

    @source Path.expand("decoder.rs", __DIR__)
    @external_resource @source

    @doc "Returns the path of the reference `Decoder` source."
    @spec source() :: Path.t()
    def source, do: @source
  end
end
