defmodule KiwiCodec.GoldenCompatibilityTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.Schema.{Binary, Parser}
  alias KiwiCodec.Wire
  alias KiwiCodec.Wire.Varint

  test "wire primitives match OpenPencil TypeScript runtime" do
    encoded = [
      Varint.encode_uint(300),
      Varint.encode_int(-150),
      Wire.encode(:string, "hi"),
      Wire.encode(:float, 1.5)
    ]

    assert IO.iodata_to_binary(encoded) == <<172, 2, 171, 2, 104, 105, 0, 127, 0, 0, 128>>
  end

  test "binary schema encoding matches OpenPencil TypeScript runtime" do
    schema =
      Parser.parse!("""
      enum Kind { NONE = 0; }
      struct Point { float x; float y; }
      message Thing { uint id = 1; string name = 2; Point pos = 3; }
      """)

    assert Binary.encode(schema) ==
             <<3, 75, 105, 110, 100, 0, 0, 1, 78, 79, 78, 69, 0, 0, 0, 0, 80, 111, 105, 110, 116,
               0, 1, 2, 120, 0, 9, 0, 1, 121, 0, 9, 0, 2, 84, 104, 105, 110, 103, 0, 2, 3, 105,
               100, 0, 7, 0, 1, 110, 97, 109, 101, 0, 11, 0, 2, 112, 111, 115, 0, 2, 0, 3>>
  end
end
