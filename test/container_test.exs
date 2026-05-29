defmodule KiwiCodec.ContainerTest do
  use ExUnit.Case, async: true

  test "builds and parses chunk containers" do
    schema = KiwiCodec.Container.deflate("schema")
    data = KiwiCodec.Container.deflate("data")

    parsed = KiwiCodec.Container.build([schema, data]) |> KiwiCodec.Container.parse()

    assert parsed.magic == "fig-kiwi"
    assert parsed.version == 101
    assert Enum.map(parsed.chunks, &KiwiCodec.Container.inflate/1) == ["schema", "data"]
  end
end
