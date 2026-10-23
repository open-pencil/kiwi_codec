defmodule KiwiCodec.RustlerGenerator.UnknownFields do
  use RustQ.Meta

  @moduledoc """
  Selects how generated Rustler decoders handle message fields the compiled
  schema does not define.

  Every generated message decoder calls `kiwi_unknown_field(decoder, definition,
  field)` for such a field and continues with the next one when it returns.

    * `:error` rejects the data with `Error::BadArg`.
    * `:runtime_schema` skips the field using a `KiwiRuntimeSchema` decoded from
      the schema that accompanies the data. The caller's `Decoder<'a>` must
      expose it as `fn runtime_schema(&self) -> Option<&'a KiwiRuntimeSchema>`
      (returning `None` keeps the `:error` behavior), and provide
      `read_string_value`, `skip_string`, and `skip_byte_array` in addition to
      the primitive readers.

  The runtime schema only skips values; decoded output is unchanged. Kiwi
  struct layouts cannot be extended compatibly, so a schema that changes a
  struct the compiled decoders read is not supported.
  """

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Type, as: R

  @runtime_schema_template Path.expand("templates/unknown_field_runtime_schema.rs", __DIR__)
  @external_resource @runtime_schema_template

  @type mode :: :error | :runtime_schema

  @doc """
  Returns the Rust items implementing `mode`.
  """
  @spec fragments(mode()) :: [RustQ.Rust.Fragment.t()]
  def fragments(:error), do: MetaAST.functions!(__MODULE__, [:kiwi_unknown_field])

  def fragments(:runtime_schema) do
    source = @runtime_schema_template |> File.read!() |> String.trim_trailing()
    [RustQ.Rust.fragment(:item, source)]
  end

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
