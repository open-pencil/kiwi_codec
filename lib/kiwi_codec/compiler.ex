defmodule KiwiCodec.Compiler do
  @moduledoc """
  Compiles `.kiwi` schema text into Elixir modules or source files.
  """

  @doc """
  Compiles schema text into Elixir modules in memory.

  This is intended for tests and tooling. Application code should usually use
  `generate_files!/2` through `mix kiwi.gen` and compile generated source files
  with the project.
  """
  @spec compile_string!(String.t(), keyword()) :: [module()]
  def compile_string!(text, opts) when is_binary(text) and is_list(opts) do
    text
    |> KiwiCodec.parse_schema!()
    |> compile_schema!(opts)
  end

  @doc """
  Compiles a parsed schema into Elixir modules in memory.
  """
  @spec compile_schema!(KiwiCodec.Schema.t(), keyword()) :: [module()]
  def compile_schema!(schema, opts) when is_list(opts) do
    schema
    |> KiwiCodec.Generator.generate(module_prefix: module_prefix!(opts), base_path: "")
    |> Enum.flat_map(fn {_path, code} -> Code.compile_string(code) end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
  Generates Elixir source files from schema text.
  """
  @spec generate_files!(String.t(), keyword()) :: [Path.t()]
  def generate_files!(text, opts) when is_binary(text) and is_list(opts) do
    text
    |> KiwiCodec.parse_schema!()
    |> generate_schema_files!(opts)
  end

  @doc """
  Generates Elixir source files from a parsed schema.
  """
  @spec generate_schema_files!(KiwiCodec.Schema.t(), keyword()) :: [Path.t()]
  def generate_schema_files!(schema, opts) when is_list(opts) do
    out = Keyword.get(opts, :out, "lib")

    schema
    |> KiwiCodec.Generator.generate(module_prefix: module_prefix!(opts), base_path: out)
    |> Enum.map(fn {path, content} ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
      path
    end)
  end

  defp module_prefix!(opts), do: Keyword.fetch!(opts, :module_prefix)
end
