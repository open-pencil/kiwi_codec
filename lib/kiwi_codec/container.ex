defmodule KiwiCodec.Container do
  @moduledoc """
  Helpers for Kiwi chunk containers with an 8-byte magic and little-endian chunk lengths.
  """

  @default_magic "fig-kiwi"
  @default_version 101

  @type parsed :: %{magic: binary(), version: non_neg_integer(), chunks: [binary()]}

  @spec parse(binary(), binary()) :: parsed()
  def parse(binary, magic \\ @default_magic) when is_binary(binary) and is_binary(magic) do
    magic_size = byte_size(magic)

    case binary do
      <<^magic::binary-size(magic_size), version::32-little, rest::binary>> ->
        %{magic: magic, version: version, chunks: parse_chunks(rest, [])}

      _ ->
        raise KiwiCodec.DecodeError, message: "invalid Kiwi container magic"
    end
  end

  @spec build([iodata()], keyword()) :: binary()
  def build(chunks, opts \\ []) when is_list(chunks) do
    magic = Keyword.get(opts, :magic, @default_magic)
    version = Keyword.get(opts, :version, @default_version)

    [
      magic,
      <<version::32-little>>,
      Enum.map(chunks, fn chunk ->
        binary = IO.iodata_to_binary(chunk)
        [<<byte_size(binary)::32-little>>, binary]
      end)
    ]
    |> IO.iodata_to_binary()
  end

  @spec deflate(iodata()) :: binary()
  def deflate(data), do: data |> IO.iodata_to_binary() |> :zlib.zip()

  @spec inflate(binary()) :: binary()
  def inflate(data) when is_binary(data), do: :zlib.unzip(data)

  defp parse_chunks("", acc), do: Enum.reverse(acc)

  defp parse_chunks(<<length::32-little, chunk::binary-size(length), rest::binary>>, acc) do
    parse_chunks(rest, [chunk | acc])
  end

  defp parse_chunks(_binary, _acc) do
    raise KiwiCodec.DecodeError, message: "truncated Kiwi container"
  end
end
