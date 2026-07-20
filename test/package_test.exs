defmodule KiwiCodec.PackageTest do
  use ExUnit.Case, async: true

  test "ships runtime and development generator sources separately" do
    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    assert "lib" in files
    assert "codegen" in files
    assert "guides" in files
  end

  test "limits RustQ to development and test compilation" do
    {_app, _requirement, opts} =
      Mix.Project.config()
      |> Keyword.fetch!(:deps)
      |> Enum.find(&(elem(&1, 0) == :rustq))

    assert Keyword.fetch!(opts, :only) == [:dev, :test]
    refute Keyword.get(opts, :runtime, true)
  end
end
