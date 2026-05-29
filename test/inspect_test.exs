defmodule KiwiCodec.InspectTest do
  use ExUnit.Case, async: true

  defmodule Point do
    use KiwiCodec, kind: :struct

    field(:x, 1, type: :float)
    field(:y, 2, type: :float)
  end

  defmodule Node do
    use KiwiCodec, kind: :message

    field(:id, 1, type: :uint)
    field(:name, 2, type: :string)
    field(:position, 3, type: Point)
  end

  test "struct inspect includes all fields" do
    assert inspect(%Point{x: 1.5, y: -2.0}) == "#KiwiCodec.InspectTest.Point<x: 1.5, y: -2.0>"
  end

  test "message inspect omits nil fields" do
    assert inspect(%Node{id: 1}) == "#KiwiCodec.InspectTest.Node<id: 1>"
  end

  test "message inspect includes nested values" do
    node = %Node{id: 1, name: "demo", position: %Point{x: 1.0, y: 2.0}}

    assert inspect(node) ==
             "#KiwiCodec.InspectTest.Node<id: 1, name: \"demo\", position: #KiwiCodec.InspectTest.Point<x: 1.0, y: 2.0>>"
  end

  test "message inspect respects limits" do
    assert inspect(%Node{id: 1, name: "demo"}, limit: 1) ==
             "#KiwiCodec.InspectTest.Node<id: 1...>"
  end
end
