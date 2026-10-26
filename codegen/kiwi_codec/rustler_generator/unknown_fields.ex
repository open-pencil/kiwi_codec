if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.UnknownFields do
    use RustQ.Meta

    @moduledoc """
    Selects how generated Rustler decoders handle message fields the compiled
    schema does not define.

    Every generated message decoder calls `kiwi_unknown_field(decoder, definition,
    field)` for such a field and continues with the next one when it returns.

      * `:error` rejects the data with `Error::BadArg`.
      * `:runtime_schema` skips the field using a `KiwiRuntimeSchema` decoded from
        the schema that accompanies the data, which the `Decoder` returns from
        `runtime_schema()`; see `KiwiCodec.RustlerGenerator.Decoder`.

    The runtime schema only skips values; decoded output is unchanged. Kiwi
    struct layouts cannot be extended compatibly, so a schema that changes a
    struct the compiled decoders read is not supported.
    """

    alias RustQ.Type, as: R

    @doc """
    Returns the Rust items implementing `mode`.
    """
    @spec fragments(:error | :runtime_schema) :: [RustQ.Rust.Fragment.t()]
    def fragments(:error), do: __rustq_items__()

    def fragments(:runtime_schema),
      do: KiwiCodec.RustlerGenerator.UnknownFieldRuntimeSchema.__rustq_items__()

    def fragments(mode) do
      raise ArgumentError,
            "expected :unknown_fields to be :error or :runtime_schema, got: #{inspect(mode)}"
    end

    @spec kiwi_unknown_field(R.mut_ref(R.path(:Decoder, R.lifetime(:_))), R.str(), R.u32()) ::
            R.nif_result(R.unit())
    defrust kiwi_unknown_field(_decoder, _definition_name, _field_id) do
      {:error, badarg()}
    end
  end
end
