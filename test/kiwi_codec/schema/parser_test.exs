defmodule KiwiCodec.Schema.ParserTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.Schema.Parser

  test "parses schema definitions" do
    schema =
      Parser.parse!("""
      enum NodeType {
        NONE = 0;
        FRAME = 4;
      }

      struct Vector {
        float x;
        float y;
      }

      message NodeChange {
        uint id = 1;
        string name = 2;
        NodeType type = 3;
        Vector[] path = 4 [deprecated];
      }
      """)

    assert Enum.map(schema.definitions, & &1.name) == ["NodeType", "Vector", "NodeChange"]

    assert [%{name: "NONE", value: 0}, %{name: "FRAME", value: 4}] =
             hd(schema.definitions).variants

    assert [
             %{name: "id", id: 1},
             %{name: "name", id: 2},
             %{name: "type", type: "NodeType"},
             %{name: "path", array?: true, deprecated?: true}
           ] = List.last(schema.definitions).fields
  end

  test "requires identifiers for names and types" do
    for source <- ["message 1 { }", "message A { uint 2 = 1; }", "message A { 3 b = 1; }"] do
      assert_raise ArgumentError, ~r/expected identifier/, fn -> Parser.parse!(source) end
    end
  end
end
