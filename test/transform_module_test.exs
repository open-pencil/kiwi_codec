defmodule KiwiCodec.TransformModuleTest do
  use ExUnit.Case, async: true

  defmodule RenameTransform do
    @behaviour KiwiCodec.TransformModule

    @impl true
    def encode(message, _module), do: %{message | name: String.upcase(message.name)}

    @impl true
    def decode(message, _module), do: %{message | name: String.downcase(message.name)}
  end

  defmodule Item do
    use KiwiCodec, kind: :message

    field(:name, 1, type: :string)

    def transform_module, do: RenameTransform
  end

  test "runs transform module before encode and after decode" do
    assert KiwiCodec.encode(%Item{name: "hello"}) == <<1, "HELLO", 0, 0>>
    assert KiwiCodec.decode(<<1, "HELLO", 0, 0>>, Item) == %Item{name: "hello"}
  end
end
