defmodule KiwiCodecRuntimeConsumer.Node do
  use KiwiCodec, kind: :message

  field :id, 1, type: :uint
  field :name, 2, type: :string
end

defmodule KiwiCodecRuntimeConsumer do
  alias KiwiCodecRuntimeConsumer.Node

  def verify do
    value = struct(Node, id: 42, name: "package")

    decoded = value |> KiwiCodec.encode() |> KiwiCodec.decode(Node)

    decoded == value and
      :code.is_loaded(RustQ) == false and
      :code.is_loaded(Reach) == false and
      Code.ensure_loaded?(KiwiCodec.RustlerGenerator) == false
  end
end
