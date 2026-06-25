defmodule KiwiCodec.FieldProps do
  @moduledoc """
  Metadata for one Kiwi field in a generated module.
  """

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          name: atom() | nil,
          source_name: String.t() | nil,
          type: atom() | {:enum, module()} | module() | nil,
          repeated?: boolean(),
          deprecated?: boolean()
        }

  defstruct id: nil,
            name: nil,
            source_name: nil,
            type: nil,
            repeated?: false,
            deprecated?: false
end
