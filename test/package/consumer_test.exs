defmodule KiwiCodec.PackageConsumerTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 300_000

  setup_all do
    root = File.cwd!()

    workspace =
      Path.join(System.tmp_dir!(), "kiwi-codec-package-#{System.unique_integer([:positive])}")

    package = Path.join(workspace, "package")
    File.mkdir_p!(workspace)
    on_exit(fn -> File.rm_rf!(workspace) end)

    run!(root, "mix", ["hex.build", "--unpack", "--output", package])

    %{root: root, workspace: workspace, package: package}
  end

  test "unpacked package compiles as a runtime-only consumer", context do
    consumer = copy_fixture!(context, "runtime_consumer")
    env = [{"KIWI_CODEC_PACKAGE_PATH", context.package}, {"MIX_ENV", "prod"}]
    run!(consumer, "mix", ["deps.get"], env)

    lock = File.read!(Path.join(consumer, "mix.lock"))
    refute lock =~ ~s|"rustq"|
    refute lock =~ ~s|"reach"|

    run!(consumer, "mix", ["test", "--warnings-as-errors"], env)
  end

  test "unpacked package generates Rust where the consumer depends on RustQ", context do
    consumer = copy_fixture!(context, "generator_consumer")
    env = [{"KIWI_CODEC_PACKAGE_PATH", context.package}]
    run!(consumer, "mix", ["deps.get"], env)
    run!(consumer, "mix", ["rustq.gen"], env)
    run!(consumer, "mix", ["test", "--warnings-as-errors"], env)

    # RustQ is a development dependency there, so production builds leave the generator out.
    run!(consumer, "mix", ["compile", "--warnings-as-errors"], [{"MIX_ENV", "prod"} | env])
  end

  defp copy_fixture!(context, name) do
    consumer = Path.join(context.workspace, name)
    File.cp_r!(Path.join([context.root, "integration", name]), consumer)
    consumer
  end

  defp run!(directory, command, args, env \\ []) do
    {output, status} =
      System.cmd(command, args,
        cd: directory,
        env: env,
        stderr_to_stdout: true
      )

    if status != 0 do
      flunk("#{command} #{Enum.join(args, " ")} failed in #{directory}:\n#{output}")
    end

    output
  end
end
