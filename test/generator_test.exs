defmodule KiwiCodec.GeneratorTest do
  use ExUnit.Case, async: true

  test "generates modules from schema" do
    schema =
      KiwiCodec.parse_schema!("""
      enum Kind {
        NONE = 0;
      }

      message Thing {
        Kind kind = 1;
        string displayName = 2;
      }
      """)

    files =
      KiwiCodec.Generator.generate(schema,
        module_prefix: Generated.Schema,
        base_path: "tmp/generated"
      )

    assert {"tmp/generated/generated/schema/thing.ex", thing} =
             List.keyfind(files, "tmp/generated/generated/schema/thing.ex", 0)

    assert thing =~ "defmodule Generated.Schema.Thing"
    assert thing =~ "field(:display_name, 2, type: :string, source_name: \"displayName\")"
  end
end
