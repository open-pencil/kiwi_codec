defmodule KiwiCodec.RustlerGenerator.RecordsTest do
  use ExUnit.Case, async: true

  defmodule NodeReader do
    @moduledoc "Reads native records through `Records`, without naming a Rust path."

    use RustQ.Meta

    alias KiwiCodec.RustlerGenerator.Records
    alias RustQ.Type, as: R

    @spec named_node?(R.ref(Records.kiwi_record())) :: R.bool()
    defrust named_node?(record) do
      record.definition() == Records.Definitions.NODE and record.has(Records.Node.NAME)
    end
  end

  test "RustQ code names the runtime's types and constants through the module" do
    source = NodeReader.__rustq_source__()

    assert source =~ "fn named_node(record: &KiwiRecord) -> bool"
    assert source =~ "kiwi_record_definitions::NODE"
    assert source =~ "record.has(kiwi_records::Node::NAME)"
  end
end
