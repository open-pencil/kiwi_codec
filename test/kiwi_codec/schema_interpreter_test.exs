defmodule KiwiCodec.SchemaInterpreterTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.SchemaInterpreter

  @schema KiwiCodec.parse_schema!("""
          enum NodeType { NONE = 0; FRAME = 4; }
          struct Vector { float x; float y; }

          message NodeChange {
            uint id = 1;
            string name = 2;
            NodeType type = 3;
            Vector position = 4;
            uint[] children = 5;
            byte[] blob = 6;
          }
          """)

  @value %{
    "id" => 42,
    "name" => "hello",
    "type" => "FRAME",
    "position" => %{"x" => 1.5, "y" => -2.25},
    "children" => [1, 2, 300],
    "blob" => <<1, 2, 3>>
  }

  test "encodes and decodes with a schema or a prepared one" do
    binary = SchemaInterpreter.encode(@schema, "NodeChange", @value)
    prepared = SchemaInterpreter.prepare(@schema)

    assert SchemaInterpreter.decode(@schema, "NodeChange", binary) == @value
    assert SchemaInterpreter.encode(prepared, "NodeChange", @value) == binary
    assert SchemaInterpreter.decode(prepared, "NodeChange", binary) == @value
  end

  test "skips one message field and returns the bytes after it" do
    <<2, value_and_end::binary>> =
      SchemaInterpreter.encode(@schema, "NodeChange", %{"name" => "x"})

    assert SchemaInterpreter.skip_message_field(@schema, "NodeChange", 2, value_and_end) == <<0>>
  end
end
