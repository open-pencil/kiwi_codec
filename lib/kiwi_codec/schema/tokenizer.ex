defmodule KiwiCodec.Schema.Tokenizer do
  @moduledoc """
  Tokenizes `.kiwi` schema text with source positions.

  Tokens are identifiers, integers with an optional leading `-`, and the symbols `=`, `;`, `{`,
  `}`, `[]`, and `[deprecated]`. Whitespace and `//` comments separate them. The last token is
  an empty `:eof` token marking where the text ends.
  """

  alias KiwiCodec.Schema.Token

  @symbols ["[deprecated]", "[]", "=", ";", "{", "}"]

  defguardp identifier_start?(char) when char in ?a..?z or char in ?A..?Z or char == ?_
  defguardp identifier_char?(char) when identifier_start?(char) or char in ?0..?9

  @spec tokenize(String.t()) :: [Token.t()]
  def tokenize(text) when is_binary(text), do: tokenize(text, 1, 1, [])

  defp tokenize("", line, column, tokens),
    do: Enum.reverse([%Token{kind: :eof, text: "", line: line, column: column} | tokens])

  defp tokenize("\n" <> rest, line, _column, tokens), do: tokenize(rest, line + 1, 1, tokens)

  defp tokenize(<<char, rest::binary>>, line, column, tokens) when char in [?\s, ?\t, ?\r],
    do: tokenize(rest, line, column + 1, tokens)

  defp tokenize("//" <> rest, line, column, tokens) do
    {comment, rest} = take_line(rest)
    tokenize(rest, line, column + 2 + String.length(comment), tokens)
  end

  defp tokenize(<<char, _::binary>> = text, line, column, tokens) when identifier_start?(char),
    do: take(text, :identifier, take_while(text, &identifier_char?(&1)), line, column, tokens)

  defp tokenize(<<char, _::binary>> = text, line, column, tokens) when char in ?0..?9,
    do: integer(text, 0, line, column, tokens)

  defp tokenize(<<?-, char, _::binary>> = text, line, column, tokens) when char in ?0..?9,
    do: integer(text, 1, line, column, tokens)

  defp tokenize(text, line, column, tokens) do
    case Enum.find(@symbols, &String.starts_with?(text, &1)) do
      nil -> unexpected!(text, line, column)
      symbol -> take(text, :symbol, symbol, line, column, tokens)
    end
  end

  # An integer ends at a word boundary, so `12ab` is not an integer followed by a name.
  defp integer(text, sign_size, line, column, tokens) do
    size = span(text, &(&1 in ?0..?9), sign_size)

    case text do
      <<_::binary-size(^size), char, _::binary>> when identifier_char?(char) ->
        unexpected!(text, line, column)

      _rest ->
        take(text, :integer, binary_part(text, 0, size), line, column, tokens)
    end
  end

  defp take(text, kind, token_text, line, column, tokens) do
    size = byte_size(token_text)
    rest = binary_part(text, size, byte_size(text) - size)
    token = %Token{kind: kind, text: token_text, line: line, column: column}
    tokenize(rest, line, column + String.length(token_text), [token | tokens])
  end

  defp take_while(text, char?), do: binary_part(text, 0, span(text, char?, 0))

  defp span(text, char?, size) do
    case text do
      <<_::binary-size(^size), char, _::binary>> ->
        if char?.(char), do: span(text, char?, size + 1), else: size

      _end ->
        size
    end
  end

  defp take_line(text) do
    case :binary.split(text, "\n") do
      [comment, rest] -> {comment, "\n" <> rest}
      [comment] -> {comment, ""}
    end
  end

  # Reports the input up to the next whitespace or symbol, or the one character that starts one,
  # such as a `[` that is not `[]`.
  @spec unexpected!(String.t(), pos_integer(), pos_integer()) :: no_return()
  defp unexpected!(text, line, column) do
    part =
      case take_while(text, &(&1 not in ~c" \t\r\n=;{}[")) do
        "" -> String.first(text)
        part -> part
      end

    Token.parse_error!(%Token{text: part, line: line, column: column}, "unexpected input")
  end
end
