if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Field do
    @moduledoc """
    How a generated decoder reads or skips a schema field: once, repeated for an array, or as
    a whole byte array for `byte[]`.
    """

    alias KiwiCodec.RustlerGenerator.Name

    @doc """
    Whether a field reads repeated, and the function reading one value of it as a term, with
    `decoder` naming a definition's decoder.
    """
    @spec read(map(), (String.t() -> atom())) :: {boolean(), atom()}
    def read(%{array?: true, type: "byte"}, _decoder), do: {false, Name.value_function("bytes")}

    def read(%{array?: array?, type: type}, decoder),
      do: {array?, Name.read_function(type, decoder)}

    @doc "Whether a field skips repeated or as bytes, and the function skipping one value."
    @spec skip(map(), map()) :: {boolean(), boolean(), atom()}
    def skip(%{array?: true, type: "byte"}, _definition_map),
      do: {false, true, Name.skip_value_function("bytes")}

    def skip(%{array?: array?, type: type}, definition_map),
      do: {array?, false, Name.skip_type_function(type, definition_map)}

    @doc "A field's rows for a sparse decoder: id, key, and how to read it."
    @spec sparse_row(map()) :: keyword()
    def sparse_row(field) do
      {repeated?, decode} = read(field, &Name.sparse_function/1)

      [
        field_id: field.id,
        field_name: Name.field_name(field.name),
        field_repeated: repeated?,
        field_decode: decode
      ]
    end

    @doc "A field's row for a skip decoder: how to skip it."
    @spec skip_row(map(), map()) :: keyword()
    def skip_row(field, definition_map) do
      {repeated?, bytes?, skip} = skip(field, definition_map)
      [field_repeated: repeated?, field_bytes: bytes?, field_skip: skip]
    end
  end
end
