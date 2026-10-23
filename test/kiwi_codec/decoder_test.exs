defmodule KiwiCodec.DecoderTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.SchemaInterpreter

  @compiled """
  message EvolvingNode {
    string name = 1;
    EvolvingChild child = 2;
  }

  message EvolvingChild {
    uint id = 1;
  }
  """

  # A newer schema adds fields to both messages, including one whose type the
  # compiled schema has never seen.
  @written """
  message EvolvingNode {
    string name = 1;
    EvolvingChild child = 2;
    uint count = 3;
    EvolvingAudio[] audio = 4;
  }

  message EvolvingChild {
    uint id = 1;
    string label = 2;
  }

  struct EvolvingPoint {
    float x;
    float y;
  }

  message EvolvingAudio {
    string name = 1;
    EvolvingPoint origin = 2;
    byte[] data = 3;
  }
  """

  setup_all do
    KiwiCodec.ModuleCompiler.compile_string!(@compiled, module_prefix: KiwiCodec.EvolutionTest)
    written = KiwiCodec.parse_schema!(@written)

    binary =
      SchemaInterpreter.encode(written, "EvolvingNode", %{
        "name" => "frame",
        "count" => 3,
        "child" => %{"id" => 7, "label" => "new"},
        "audio" => [
          %{"name" => "beep", "origin" => %{"x" => 1.5, "y" => 2.0}, "data" => <<1, 2, 3>>}
        ]
      })

    {:ok, binary: binary, written: written}
  end

  describe "decode/3 with data written with a newer schema" do
    test "rejects fields the generated modules do not define without a schema", %{binary: binary} do
      assert_raise KiwiCodec.DecodeError,
                   ~r/unknown field 2 while decoding KiwiCodec.EvolutionTest.EvolvingChild/,
                   fn ->
                     KiwiCodec.decode(binary, KiwiCodec.EvolutionTest.EvolvingNode)
                   end
    end

    test "skips them using the schema the data was written with", %{
      binary: binary,
      written: written
    } do
      for schema <- [written, SchemaInterpreter.prepare(written)] do
        assert %{name: "frame", child: %{id: 7}} =
                 KiwiCodec.decode(binary, KiwiCodec.EvolutionTest.EvolvingNode, schema: schema)
      end
    end

    test "reports a schema without the message's definition as a decode error" do
      unrelated = KiwiCodec.parse_schema!("message Other { uint id = 1; }")

      assert_raise KiwiCodec.DecodeError,
                   ~r/error skipping unknown field 3 of KiwiCodec.EvolutionTest.EvolvingNode/,
                   fn ->
                     KiwiCodec.decode(<<3, 1, 0>>, KiwiCodec.EvolutionTest.EvolvingNode,
                       schema: unrelated
                     )
                   end
    end
  end
end
