defmodule KiwiCodec.Schema.BinaryTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.Schema.Binary
  alias KiwiCodec.Schema.Parser

  test "round-trips a schema" do
    schema =
      Parser.parse!("""
      enum NodeType { NONE = 0; FRAME = 4; }
      struct Vector { float x; float y; }
      message NodeChange { uint id = 1; NodeType type = 3; Vector[] path = 4; byte[] blob = 6; }
      """)

    assert clear_locations(Binary.decode(Binary.encode(schema))) == clear_locations(schema)
  end

  test "encodes as the OpenPencil TypeScript runtime does" do
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

  test "raises decode errors for malformed schemas" do
    assert_raise KiwiCodec.DecodeError, ~r/invalid definition kind/, fn ->
      Binary.decode(<<1, "A", 0, 255, 0>>)
    end

    assert_raise KiwiCodec.DecodeError, ~r/unterminated string/, fn ->
      Binary.decode(<<1, "A">>)
    end

    assert_raise KiwiCodec.DecodeError, ~r/invalid binary schema/, fn ->
      Binary.decode(<<1, "A", 0, 1, 1, "x", 0, 18, 0, 1>>)
    end
  end

  defp clear_locations(schema) do
    update_in(schema.definitions, fn definitions ->
      Enum.map(definitions, fn
        %KiwiCodec.Schema.Enum{} = definition ->
          variants = Enum.map(definition.variants, &%{&1 | line: 0, column: 0})
          %{definition | variants: variants, line: 0, column: 0}

        definition ->
          fields = Enum.map(definition.fields, &%{&1 | line: 0, column: 0})
          %{definition | fields: fields, line: 0, column: 0}
      end)
    end)
  end
end
