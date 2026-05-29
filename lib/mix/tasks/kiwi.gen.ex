defmodule Mix.Tasks.Kiwi.Gen do
  @moduledoc """
  Generates Elixir modules from a `.kiwi` schema.

      mix kiwi.gen schema.fig.kiwi --module-prefix MyApp.Schema --out lib/generated
  """

  use Mix.Task

  @shortdoc "Generates Elixir modules from a .kiwi schema"

  @impl Mix.Task
  def run(argv) do
    {opts, args, invalid} =
      OptionParser.parse(argv, strict: [module_prefix: :string, out: :string])

    if invalid != [] or is_nil(opts[:module_prefix]) do
      Mix.raise("usage: mix kiwi.gen schema.kiwi --module-prefix MyApp.Schema [--out lib]")
    end

    schema_path =
      case args do
        [path] ->
          path

        _args ->
          Mix.raise("usage: mix kiwi.gen schema.kiwi --module-prefix MyApp.Schema [--out lib]")
      end

    out = Keyword.get(opts, :out, "lib")
    module_prefix = Module.concat([opts[:module_prefix]])

    schema_path
    |> File.read!()
    |> KiwiCodec.Compiler.generate_files!(module_prefix: module_prefix, out: out)
    |> Enum.each(fn path -> Mix.shell().info("* creating #{path}") end)
  end
end
