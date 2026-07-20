defmodule KiwiCodecRuntimeConsumerTest do
  use ExUnit.Case, async: true

  test "round-trips values without RustQ or generator modules" do
    assert KiwiCodecRuntimeConsumer.verify()
  end
end
