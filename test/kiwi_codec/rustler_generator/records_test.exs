defmodule KiwiCodec.RustlerGenerator.RecordsTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.Test.NodeReader

  test "RustQ code names the runtime's types and constants through the module" do
    source = NodeReader.__rustq_source__()

    assert source =~ "fn named_node(record: &KiwiRecord) -> bool"
    assert source =~ "kiwi_record_definitions::NODE"
    assert source =~ "record.has(kiwi_records::Node::NAME)"
  end
end
