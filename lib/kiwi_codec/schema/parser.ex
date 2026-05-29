defmodule KiwiCodec.Schema.Parser do
  @moduledoc """
  Parser for `.kiwi` schema text.
  """

  alias KiwiCodec.Schema
  alias KiwiCodec.Schema.{Definition, Field}

  @reserved_names ~w(ByteBuffer package)
  @token_pattern ~r/((?:-|\b)\d+\b|[=;{}]|\[\]|\[deprecated\]|\b[A-Za-z_][A-Za-z0-9_]*\b|\/\/.*|\s+)/

  @spec parse!(String.t()) :: Schema.t()
  def parse!(text) when is_binary(text) do
    text
    |> tokenize()
    |> parse_tokens()
    |> verify!()
  end

  defp tokenize(text) do
    {tokens, line, column} =
      Regex.split(@token_pattern, text, include_captures: true, trim: false)
      |> Enum.reduce({[], 1, 1}, fn part, {tokens, line, column} ->
        token? = Regex.match?(@token_pattern, part) and not Regex.match?(~r/^(\/\/.*|\s+)$/, part)

        tokens =
          if token? and part != "",
            do: [%{text: part, line: line, column: column} | tokens],
            else: tokens

        {line, column} = advance_position(part, line, column)
        {tokens, line, column}
      end)

    Enum.reverse([%{text: "", line: line, column: column} | tokens])
  end

  defp advance_position(part, line, column) do
    case String.split(part, "\n") do
      [_single] -> {line, column + String.length(part)}
      parts -> {line + length(parts) - 1, String.length(List.last(parts)) + 1}
    end
  end

  defp parse_tokens(tokens) do
    {package, rest} = parse_package(tokens)
    {definitions, rest} = parse_definitions(rest, [])
    expect!(rest, "")
    %Schema{package: package, definitions: Enum.reverse(definitions)}
  end

  defp parse_package([%{text: "package"}, token | rest]) do
    expect_identifier!(token)
    {_, rest} = expect!(rest, ";")
    {token.text, rest}
  end

  defp parse_package(tokens), do: {nil, tokens}

  defp parse_definitions([%{text: ""} | _] = tokens, acc), do: {acc, tokens}

  defp parse_definitions([kind_token, name_token | rest], acc) do
    kind = parse_kind!(kind_token)
    expect_identifier!(name_token)
    {_, rest} = expect!(rest, "{")
    {fields, rest} = parse_fields(rest, kind, [])

    definition = %Definition{
      name: name_token.text,
      kind: kind,
      fields: Enum.reverse(fields),
      line: name_token.line,
      column: name_token.column
    }

    parse_definitions(rest, [definition | acc])
  end

  defp parse_kind!(%{text: "enum"}), do: :enum
  defp parse_kind!(%{text: "struct"}), do: :struct
  defp parse_kind!(%{text: "message"}), do: :message
  defp parse_kind!(token), do: parse_error!(token, "expected definition kind")

  defp parse_fields([%{text: "}"} | rest], _kind, acc), do: {acc, rest}

  defp parse_fields(tokens, :enum, acc) do
    [name_token | rest] = tokens
    expect_identifier!(name_token)
    {_, rest} = expect!(rest, "=")
    [value_token | rest] = rest
    value = parse_integer!(value_token)
    {_, rest} = expect!(rest, ";")

    field = %Field{
      name: name_token.text,
      value: value,
      line: name_token.line,
      column: name_token.column
    }

    parse_fields(rest, :enum, [field | acc])
  end

  defp parse_fields([type_token | rest], kind, acc) do
    expect_identifier!(type_token)
    {array?, rest} = parse_array(rest)
    [name_token | rest] = rest
    expect_identifier!(name_token)

    {value, rest} =
      if kind == :struct do
        {length(acc) + 1, rest}
      else
        {_, rest} = expect!(rest, "=")
        [value_token | rest] = rest
        {parse_integer!(value_token), rest}
      end

    {deprecated?, rest} = parse_deprecated(rest)
    {_, rest} = expect!(rest, ";")

    field = %Field{
      name: name_token.text,
      type: type_token.text,
      array?: array?,
      deprecated?: deprecated?,
      value: value,
      line: name_token.line,
      column: name_token.column
    }

    parse_fields(rest, kind, [field | acc])
  end

  defp parse_array([%{text: "[]"} | rest]), do: {true, rest}
  defp parse_array(rest), do: {false, rest}

  defp parse_deprecated([%{text: "[deprecated]"} | rest]), do: {true, rest}
  defp parse_deprecated(rest), do: {false, rest}

  defp expect!([%{text: expected} = token | rest], expected), do: {token, rest}

  defp expect!([token | _rest], expected),
    do: parse_error!(token, "expected #{inspect(expected)}")

  defp expect_identifier!(%{text: text} = token) do
    unless Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_]*$/, text),
      do: parse_error!(token, "expected identifier")
  end

  defp parse_integer!(%{text: text} = token) do
    case Integer.parse(text) do
      {value, ""} -> value
      _ -> parse_error!(token, "expected integer")
    end
  end

  defp verify!(%Schema{} = schema) do
    defined = Enum.map(schema.definitions, & &1.name)
    duplicates = defined -- Enum.uniq(defined)

    cond do
      duplicates != [] ->
        raise ArgumentError, "duplicate definition #{inspect(hd(duplicates))}"

      Enum.any?(defined, &(&1 in @reserved_names)) ->
        raise ArgumentError, "reserved definition name"

      true ->
        verify_definitions!(schema, defined)
    end
  end

  defp verify_definitions!(schema, defined) do
    Enum.each(schema.definitions, fn definition ->
      verify_field_names!(definition)
      verify_field_values!(definition)
      verify_field_types!(definition, defined)
    end)

    schema
  end

  defp verify_field_names!(definition) do
    names = Enum.map(definition.fields, & &1.name)

    if names != Enum.uniq(names) do
      raise ArgumentError, "duplicate field name in #{definition.name}"
    end
  end

  defp verify_field_values!(%Definition{kind: :struct}), do: :ok

  defp verify_field_values!(definition) do
    values = Enum.map(definition.fields, & &1.value)

    if values != Enum.uniq(values) do
      raise ArgumentError, "duplicate field value in #{definition.name}"
    end
  end

  defp verify_field_types!(%Definition{kind: :enum}, _defined), do: :ok

  defp verify_field_types!(definition, defined) do
    Enum.each(definition.fields, fn field ->
      unless Schema.native_type?(field.type) or field.type in defined do
        raise ArgumentError,
              "unknown type #{inspect(field.type)} for #{definition.name}.#{field.name}"
      end
    end)
  end

  defp parse_error!(token, message) do
    raise ArgumentError, "#{message} at #{token.line}:#{token.column}, got #{inspect(token.text)}"
  end
end
