defmodule KiwiCodec.Schema.TokenizerTest do
  use ExUnit.Case, async: true

  alias KiwiCodec.Schema.Tokenizer

  test "reads identifiers, integers, and symbols with their positions" do
    tokens = Tokenizer.tokenize("enum E {\n  A = -1; // first\n  B = 2;\n}\nint[] x [deprecated]")

    assert Enum.map(tokens, &{&1.kind, &1.text, &1.line, &1.column}) == [
             {:identifier, "enum", 1, 1},
             {:identifier, "E", 1, 6},
             {:symbol, "{", 1, 8},
             {:identifier, "A", 2, 3},
             {:symbol, "=", 2, 5},
             {:integer, "-1", 2, 7},
             {:symbol, ";", 2, 9},
             {:identifier, "B", 3, 3},
             {:symbol, "=", 3, 5},
             {:integer, "2", 3, 7},
             {:symbol, ";", 3, 8},
             {:symbol, "}", 4, 1},
             {:identifier, "int", 5, 1},
             {:symbol, "[]", 5, 4},
             {:identifier, "x", 5, 7},
             {:symbol, "[deprecated]", 5, 9},
             {:eof, "", 5, 21}
           ]
  end

  test "rejects input that is no token" do
    for {source, message} <- [
          {"message A { uint id = 1; @ }", ~s(at 1:26, got "@")},
          {"uint id = 12ab;", ~s(at 1:11, got "12ab")},
          {"uint[ ] id;", ~s(at 1:5, got "[")},
          {"é", ~s(at 1:1, got "é")}
        ] do
      assert_raise ArgumentError, ~r/unexpected input #{Regex.escape(message)}/, fn ->
        Tokenizer.tokenize(source)
      end
    end
  end
end
