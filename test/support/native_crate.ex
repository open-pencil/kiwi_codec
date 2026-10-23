defmodule KiwiCodec.Test.NativeCrate do
  @moduledoc """
  Builds generated Rustler decoders into NIF libraries the tests can call.

  Every crate goes into one Cargo workspace under `_build`, so Rustler compiles once and
  later runs reuse it. A crate's `lib.rs` declares the reference `Decoder` from
  `KiwiCodec.RustlerGenerator.Decoder`, includes the generated source, and adds the caller's
  Rust, which defines `RuntimeSchema` and any NIFs wrapping generated functions.
  """

  @runtime KiwiCodec.RustlerGenerator.Decoder.source()

  @typedoc "A crate to build: its name, the Elixir module that loads it, and its Rust."
  @type crate :: %{
          name: String.t(),
          module: module(),
          generated: String.t(),
          rust: String.t(),
          nifs: [{atom(), arity()}]
        }

  @doc """
  Builds `crates` and loads each into its module, which gets a stub for every NIF.

  Raises with rustc's rendered errors when a crate does not compile.
  """
  @spec build!([crate()]) :: :ok
  def build!(crates) do
    root = Path.join(Mix.Project.build_path(), "kiwi_native_crates")
    File.mkdir_p!(root)

    for crate <- crates, do: write_crate!(root, crate)

    members = Enum.map_join(crates, ", ", &inspect(&1.name))

    File.write!(Path.join(root, "Cargo.toml"), """
    [workspace]
    resolver = "2"
    members = [#{members}]

    [profile.dev]
    debug = false
    """)

    libraries = cargo_build!(root)
    Enum.each(crates, &load!(&1, Map.fetch!(libraries, &1.name), root))
  end

  defp write_crate!(root, crate) do
    dir = Path.join(root, crate.name)
    File.mkdir_p!(Path.join(dir, "src"))

    File.write!(Path.join(dir, "Cargo.toml"), """
    [package]
    name = #{inspect(crate.name)}
    version = "0.0.0"
    edition = "2021"
    publish = false

    [lib]
    crate-type = ["cdylib"]

    [dependencies]
    rustler = "0.39"
    """)

    File.cp!(@runtime, Path.join([dir, "src", "runtime.rs"]))
    File.write!(Path.join([dir, "src", "generated.rs"]), crate.generated)

    File.write!(Path.join([dir, "src", "lib.rs"]), """
    mod runtime;

    include!("generated.rs");

    #{crate.rust}

    rustler::init!(#{inspect(Atom.to_string(crate.module))});
    """)
  end

  defp cargo_build!(root) do
    {output, status} =
      System.cmd("cargo", ["build", "--message-format", "json"],
        cd: root,
        env: [{"CARGO_TARGET_DIR", Path.join(root, "target")}],
        stderr_to_stdout: false
      )

    messages =
      output
      |> String.split("\n", trim: true)
      |> Enum.flat_map(fn line ->
        case JSON.decode(line) do
          {:ok, message} -> [message]
          {:error, _reason} -> []
        end
      end)

    errors =
      for %{"reason" => "compiler-message", "message" => %{"level" => "error"} = message} <-
            messages,
          do: message["rendered"]

    if status != 0 or errors != [] do
      raise "generated Rust does not compile:\n\n#{Enum.join(errors, "\n")}"
    end

    for %{"reason" => "compiler-artifact", "target" => %{"kind" => ["cdylib"]} = target} =
          artifact <- messages,
        into: %{},
        do: {target["name"], hd(artifact["filenames"])}
  end

  defp load!(crate, library, root) do
    # Erlang loads `<path>.so` on every Unix, whatever the platform calls a shared library.
    path = Path.join([root, "lib", crate.name])
    File.mkdir_p!(Path.dirname(path))
    File.cp!(library, path <> ".so")

    stubs =
      for {name, arity} <- crate.nifs do
        args = Macro.generate_arguments(arity, __MODULE__)
        quote do: def(unquote(name)(unquote_splicing(args)), do: :erlang.nif_error(:not_loaded))
      end

    :code.purge(crate.module)
    :code.delete(crate.module)

    Module.create(
      crate.module,
      quote do
        unquote_splicing(stubs)

        def __load__(path), do: :erlang.load_nif(String.to_charlist(path), 0)
      end,
      Macro.Env.location(__ENV__)
    )

    :ok = crate.module.__load__(path)
  end
end
