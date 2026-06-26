defmodule KiwiCodec.FileGenerator do
  @moduledoc """
  Writes generated Elixir source files from `.kiwi` schema text or parsed schemas.
  """

  @spec generate_files!(String.t(), keyword()) :: [Path.t()]
  def generate_files!(text, opts) when is_binary(text) and is_list(opts) do
    text
    |> KiwiCodec.parse_schema!()
    |> generate_schema_files!(opts)
  end

  @spec generate_schema_files!(KiwiCodec.Schema.t(), keyword()) :: [Path.t()]
  def generate_schema_files!(schema, opts) when is_list(opts) do
    out = Keyword.get(opts, :out, "lib")

    schema
    |> KiwiCodec.ModuleGenerator.generate(module_prefix: module_prefix!(opts), base_path: out)
    |> Enum.map(fn {path, content} ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
      path
    end)
  end

  defp module_prefix!(opts), do: Keyword.fetch!(opts, :module_prefix)
end
