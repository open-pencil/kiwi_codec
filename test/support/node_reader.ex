defmodule KiwiCodec.Test.NodeReader do
  @moduledoc """
  RustQ code reading native records through `KiwiCodec.RustlerGenerator.Records`, without
  naming a Rust path. The native tests build its Rust with the records feature.
  """

  use RustQ.Meta

  alias KiwiCodec.RustlerGenerator.Records
  alias RustQ.Type, as: R

  @spec named_node?(R.ref(Records.kiwi_record())) :: R.bool()
  defrust named_node?(record) do
    record.definition() == Records.Definitions.NODE and record.has(Records.Node.NAME)
  end
end
