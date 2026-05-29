defmodule KiwiCodecTest do
  use ExUnit.Case, async: true

  defmodule ExampleKind do
    use KiwiCodec, kind: :enum

    enum_value(:none, 0)
    enum_value(:frame, 4)
  end

  defmodule Point do
    use KiwiCodec, kind: :struct

    field(:x, 1, type: :float)
    field(:y, 2, type: :float)
  end

  defmodule Node do
    use KiwiCodec, kind: :message

    field(:id, 1, type: :uint)
    field(:name, 2, type: :string)
    field(:kind, 3, type: {:enum, ExampleKind})
    field(:position, 4, type: Point)
    field(:children, 5, type: :uint, repeated: true)
    field(:blob, 6, type: :byte, repeated: true)
  end

  test "round-trips primitive and nested fields" do
    node = %Node{
      id: 42,
      name: "hello",
      kind: :frame,
      position: %Point{x: 1.5, y: -2.25},
      children: [1, 2, 300],
      blob: <<1, 2, 3>>
    }

    assert node |> KiwiCodec.encode() |> KiwiCodec.decode(Node) == node
  end

  test "skips nil message fields" do
    assert KiwiCodec.encode(%Node{id: 1}) == <<1, 1, 0>>
  end
end
