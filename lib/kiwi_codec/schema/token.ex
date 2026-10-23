defmodule KiwiCodec.Schema.Token do
  @moduledoc """
  Source token with line and column information for schema parse errors.
  """

  @type kind :: :identifier | :integer | :symbol | :eof

  @type t :: %__MODULE__{
          kind: kind() | nil,
          text: String.t(),
          line: pos_integer(),
          column: pos_integer()
        }

  defstruct kind: nil, text: "", line: 1, column: 1

  @spec parse_error!(t(), String.t()) :: no_return()
  def parse_error!(%__MODULE__{} = token, message) do
    raise ArgumentError, "#{message} at #{token.line}:#{token.column}, got #{inspect(token.text)}"
  end
end
