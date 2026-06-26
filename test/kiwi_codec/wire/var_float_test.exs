defmodule KiwiCodec.Wire.VarFloatTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.Wire.VarFloat

  test "encodes Kiwi varfloat values" do
    assert VarFloat.encode(0.0) == <<0>>
    assert VarFloat.encode(1.5) == <<127, 0, 0, 128>>
    assert VarFloat.encode(:infinity) == <<255, 0, 0, 0>>
    assert VarFloat.encode(:negative_infinity) == <<255, 1, 0, 0>>
    assert VarFloat.encode(:nan) == <<255, 0, 0, 128>>
  end

  test "decodes Kiwi varfloat values and preserves rest" do
    assert VarFloat.decode(<<0, 42>>) == {0.0, <<42>>}
    assert VarFloat.decode(<<127, 0, 0, 128, 42>>) == {1.5, <<42>>}
    assert VarFloat.decode(<<255, 0, 0, 0>>) == {:infinity, ""}
    assert VarFloat.decode(<<255, 1, 0, 0>>) == {:negative_infinity, ""}
    assert VarFloat.decode(<<255, 0, 0, 128>>) == {:nan, ""}
  end

  test "rejects truncated varfloats" do
    assert_raise KiwiCodec.DecodeError, ~r/cannot decode varfloat/, fn ->
      VarFloat.decode(<<127, 0, 0>>)
    end
  end
end
