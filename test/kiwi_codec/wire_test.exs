defmodule KiwiCodec.WireTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.Wire
  alias KiwiCodec.Wire.Varint

  test "encodes primitives as the OpenPencil TypeScript runtime does" do
    encoded = [
      Varint.encode_uint(300),
      Varint.encode_int(-150),
      Wire.encode(:string, "hi"),
      Wire.encode(:float, 1.5)
    ]

    assert IO.iodata_to_binary(encoded) == <<172, 2, 171, 2, 104, 105, 0, 127, 0, 0, 128>>
  end
end
