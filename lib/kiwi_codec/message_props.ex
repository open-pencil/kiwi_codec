defmodule KiwiCodec.MessageProps do
  @moduledoc """
  Compiled Kiwi definition metadata for generated modules.
  """

  alias KiwiCodec.FieldProps

  @type kind :: :message | :struct | :enum

  @type t :: %__MODULE__{
          kind: kind(),
          ordered_fields: [FieldProps.t()],
          fields_by_id: %{pos_integer() => FieldProps.t()},
          fields_by_name: %{atom() => FieldProps.t()},
          enum_by_name: %{atom() => integer()},
          enum_by_value: %{integer() => atom()}
        }

  defstruct kind: :message,
            ordered_fields: [],
            fields_by_id: %{},
            fields_by_name: %{},
            enum_by_name: %{},
            enum_by_value: %{}
end
