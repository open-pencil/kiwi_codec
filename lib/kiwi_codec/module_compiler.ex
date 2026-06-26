defmodule KiwiCodec.ModuleCompiler do
  @moduledoc """
  Compiles `.kiwi` schema text or parsed schemas into Elixir modules in memory.

  This is intended for tests and tooling. Application code should usually use
  `mix kiwi.gen` and compile generated source files with the project.
  """

  @spec compile_string!(String.t(), keyword()) :: [module()]
  def compile_string!(text, opts) when is_binary(text) and is_list(opts) do
    text
    |> KiwiCodec.parse_schema!()
    |> compile_schema!(opts)
  end

  @spec compile_schema!(KiwiCodec.Schema.t(), keyword()) :: [module()]
  def compile_schema!(schema, opts) when is_list(opts) do
    schema
    |> KiwiCodec.ModuleGenerator.generate(module_prefix: module_prefix!(opts), base_path: "")
    |> Enum.flat_map(fn {_path, code} -> Code.compile_string(code) end)
    |> Enum.map(&elem(&1, 0))
  end

  defp module_prefix!(opts), do: Keyword.fetch!(opts, :module_prefix)
end
