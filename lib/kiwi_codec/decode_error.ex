defmodule KiwiCodec.DecodeError do
  @moduledoc """
  Raised when Kiwi wire data or binary schema data cannot be decoded.
  """

  defexception [:message]
end
