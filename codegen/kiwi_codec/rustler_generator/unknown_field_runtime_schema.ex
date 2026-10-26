if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.UnknownFieldRuntimeSchema do
    use RustQ.Meta

    @moduledoc """
    `KiwiRuntimeSchema`, a schema read with the data, and the `kiwi_unknown_field` that skips a
    message field the compiled schema lacks with it; see
    `KiwiCodec.RustlerGenerator.UnknownFields`.
    """
  end
end
