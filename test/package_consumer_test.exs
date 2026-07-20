defmodule KiwiCodec.PackageConsumerTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 300_000

  test "unpacked package compiles as a runtime-only consumer" do
    root = File.cwd!()

    workspace =
      Path.join(System.tmp_dir!(), "kiwi-codec-package-#{System.unique_integer([:positive])}")

    package = Path.join(workspace, "package")
    consumer = Path.join(workspace, "runtime_consumer")
    File.mkdir_p!(workspace)
    on_exit(fn -> File.rm_rf!(workspace) end)

    run!(root, "mix", ["hex.build", "--unpack", "--output", package])
    File.cp_r!(Path.join([root, "integration", "runtime_consumer"]), consumer)

    env = [{"KIWI_CODEC_PACKAGE_PATH", package}, {"MIX_ENV", "prod"}]
    run!(consumer, "mix", ["deps.get"], env)

    lock = File.read!(Path.join(consumer, "mix.lock"))
    refute lock =~ ~s|"rustq"|
    refute lock =~ ~s|"reach"|

    run!(consumer, "mix", ["test", "--warnings-as-errors"], env)
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
