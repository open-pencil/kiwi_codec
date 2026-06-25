defmodule KiwiCodec.EncodeError do
  @moduledoc """
  Raised when a value cannot be encoded as Kiwi wire data.
  """

  defexception [:message]
end
