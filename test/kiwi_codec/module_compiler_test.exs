defmodule KiwiCodec.ModuleCompilerTest do
  use ExUnit.Case, async: true

  @schema_text """
  message CompilerThing {
    uint id = 1;
    string name = 2;
  }
  """

  test "compiles schema text into modules" do
    modules =
      KiwiCodec.ModuleCompiler.compile_string!(@schema_text,
        module_prefix: KiwiCodec.GeneratedTest
      )

    assert KiwiCodec.GeneratedTest.CompilerThing in modules

    module = KiwiCodec.GeneratedTest.CompilerThing
    value = struct(module, id: 7, name: "seven")

    assert value |> KiwiCodec.encode() |> KiwiCodec.decode(module) == value
  end

  test "generates source files" do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "kiwi-codec-compiler-test-#{System.unique_integer([:positive])}"
      )

    try do
      assert [path] =
               KiwiCodec.FileGenerator.generate_files!(@schema_text,
                 module_prefix: KiwiCodec.GeneratedFiles,
                 out: tmp
               )

      assert File.exists?(path)
      assert File.read!(path) =~ "defmodule KiwiCodec.GeneratedFiles.CompilerThing"
    after
      File.rm_rf!(tmp)
    end
  end
end
