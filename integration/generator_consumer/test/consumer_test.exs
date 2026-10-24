defmodule KiwiCodecGeneratorConsumerTest do
  use ExUnit.Case, async: true

  test "mix rustq.gen wrote Rustler decoders" do
    functions =
      "native/src/generated.rs"
      |> RustQ.Syn.parse_file!()
      |> RustQ.Syn.functions()
      |> Enum.map(& &1.name)

    assert "decode_node" in functions
  end
end
