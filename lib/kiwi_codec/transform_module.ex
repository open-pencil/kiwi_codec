defmodule KiwiCodec.TransformModule do
  @moduledoc """
  Hook behaviour for custom Kiwi encode/decode normalization.

  A Kiwi module can override `transform_module/0` and return a module that
  implements this behaviour. The transform is called before encoding and after
  decoding, mirroring the extension point in `elixir-protobuf`.
  """

  @callback encode(struct(), module()) :: struct()
  @callback decode(struct(), module()) :: struct()
end
