defmodule KiwiCodec.RustlerGeneratorTest do
  use ExUnit.Case, async: true

  test "renders struct decoder and entrypoint into Rust template" do
    schema =
      KiwiCodec.parse_schema!("""
      enum Kind {
        Rectangle = 1;
      }

      struct Point {
        float x;
        float y;
      }

      struct Node {
        Kind kind;
        Point position;
      }
      """)

    dir =
      Path.join(
        System.tmp_dir!(),
        "kiwi-rustler-generator-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    template = Path.join(dir, "template.rs")
    out = Path.join(dir, "generated.rs")

    File.write!(template, """
    use rustler::{Binary, Env, NifResult, Term};
    use rustler::types::atom::Atom;
    use crate::runtime::Decoder;

    kiwi_codegen::definitions!();
    kiwi_codegen::entrypoints!();
    """)

    KiwiCodec.RustlerGenerator.render!(schema,
      definitions: ["Node"],
      entrypoints: [decode_node: "Node"],
      module_prefix: "Example.Schema",
      template: template,
      out: out
    )

    generated = File.read!(out)

    assert generated =~ "fn decode_node_from_decoder"
    assert generated =~ "fn decode_point_from_decoder"
    assert generated =~ "fn decode_kind_from_decoder"
    assert generated =~ "pub fn decode_node"
    assert generated =~ ~s("Elixir.Example.Schema.Node")
    assert generated =~ "decoder.read_var_float(env)?"
    refute generated =~ "kiwi_codegen"
  end
end
