defmodule KiwiCodec.Schema do
  @moduledoc """
  Parsed Kiwi schema.
  """

  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias KiwiCodec.Schema.{Message, Struct}

  @type definition :: SchemaEnum.t() | Struct.t() | Message.t()
  @type t :: %__MODULE__{package: String.t() | nil, definitions: [definition()]}

  defstruct package: nil, definitions: []

  @spec native_type?(String.t()) :: boolean()
  def native_type?(type), do: KiwiCodec.PrimitiveType.name?(type)

  @spec definition(t(), String.t()) :: definition() | nil
  def definition(%__MODULE__{definitions: definitions}, name) do
    Elixir.Enum.find(definitions, &(&1.name == name))
  end
end

defmodule KiwiCodec.Schema.Enum do
  @moduledoc """
  Kiwi enum definition.
  """

  alias KiwiCodec.Schema.EnumVariant

  @type t :: %__MODULE__{
          name: String.t(),
          variants: [EnumVariant.t()],
          line: non_neg_integer(),
          column: non_neg_integer()
        }

  defstruct name: nil,
            variants: [],
            line: 0,
            column: 0
end

defmodule KiwiCodec.Schema.Struct do
  @moduledoc """
  Kiwi struct definition.
  """

  alias KiwiCodec.Schema.Field

  @type t :: %__MODULE__{
          name: String.t(),
          fields: [Field.t()],
          line: non_neg_integer(),
          column: non_neg_integer()
        }

  defstruct name: nil,
            fields: [],
            line: 0,
            column: 0
end

defmodule KiwiCodec.Schema.Message do
  @moduledoc """
  Kiwi message definition.
  """

  alias KiwiCodec.Schema.Field

  @type t :: %__MODULE__{
          name: String.t(),
          fields: [Field.t()],
          line: non_neg_integer(),
          column: non_neg_integer()
        }

  defstruct name: nil,
            fields: [],
            line: 0,
            column: 0
end

defmodule KiwiCodec.Schema.Field do
  @moduledoc """
  Kiwi struct or message field.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          array?: boolean(),
          deprecated?: boolean(),
          id: pos_integer(),
          line: non_neg_integer(),
          column: non_neg_integer()
        }

  defstruct name: nil,
            type: nil,
            array?: false,
            deprecated?: false,
            id: nil,
            line: 0,
            column: 0
end

defmodule KiwiCodec.Schema.EnumVariant do
  @moduledoc """
  Kiwi enum variant.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          value: integer(),
          line: non_neg_integer(),
          column: non_neg_integer()
        }

  defstruct name: nil,
            value: nil,
            line: 0,
            column: 0
end
