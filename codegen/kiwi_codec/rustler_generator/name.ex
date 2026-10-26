if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Name do
    @moduledoc """
    The Rust names generated decoders give schema definitions and the functions reading their
    values: `decode_node_change_from_decoder` decodes a `NodeChange` fully,
    `decode_sparse_node_change_from_decoder` to the fields present, and
    `skip_node_change_from_decoder` skips one.
    """

    alias KiwiCodec.PrimitiveType
    alias KiwiCodec.Schema.Enum, as: SchemaEnum
    alias RustQ.Rust.Identifier

    @doc "The function decoding a definition fully."
    @spec decoder_function(String.t()) :: atom()
    def decoder_function(name), do: function(["decode_", rust_identifier(name), "_from_decoder"])

    @doc "The function decoding a message's fields fully, into the struct's values."
    @spec message_fields_function(String.t()) :: atom()
    def message_fields_function(name),
      do: function(["decode_", rust_identifier(name), "_fields_from_decoder"])

    @doc "The function decoding a definition to the fields present."
    @spec sparse_function(String.t()) :: atom()
    def sparse_function(name),
      do: function(["decode_sparse_", rust_identifier(name), "_from_decoder"])

    @doc "The function skipping one value of a definition."
    @spec skip_function(String.t()) :: atom()
    def skip_function(name), do: function(["skip_", rust_identifier(name), "_from_decoder"])

    @doc "The function reading a primitive value as a term."
    @spec value_function(PrimitiveType.name()) :: atom()
    def value_function(type), do: function(["kiwi_", type, "_value"])

    @doc "The function skipping a primitive value."
    @spec skip_value_function(PrimitiveType.name()) :: atom()
    def skip_value_function(type), do: function(["kiwi_skip_", type, "_value"])

    @doc """
    The function reading one value of `type` as a term: a primitive's reader, or the
    definition's `decoder`, `&decoder_function/1` or `&sparse_function/1`.
    """
    @spec read_function(String.t(), (String.t() -> atom())) :: atom()
    def read_function(type, decoder) do
      if PrimitiveType.name?(type), do: value_function(type), else: decoder.(type)
    end

    @doc "The function skipping one value of `type`; an enum is a `uint` on the wire."
    @spec skip_type_function(String.t(), map()) :: atom()
    def skip_type_function(type, definition_map) do
      cond do
        PrimitiveType.name?(type) -> skip_value_function(type)
        match?(%SchemaEnum{}, Map.fetch!(definition_map, type)) -> skip_value_function("uint")
        true -> skip_function(type)
      end
    end

    @spec module_atom_static(String.t()) :: atom()
    def module_atom_static(name), do: static_name(name, "MODULE_ATOM")

    @spec struct_keys_static(String.t()) :: atom()
    def struct_keys_static(name), do: static_name(name, "STRUCT_KEYS")

    @spec module_name(String.t(), String.t()) :: String.t()
    def module_name(module_prefix, name), do: "Elixir.#{module_prefix}.#{name}"

    @spec field_name(String.t()) :: String.t()
    def field_name(name), do: Macro.underscore(name)

    @doc """
    Returns the snake_case Rust identifier for a schema name. Schema names are identifiers, and
    a name that is not, as a schema decoded from binary may hold, fails where it is rendered.
    """
    @spec rust_identifier(String.t()) :: String.t()
    def rust_identifier(name), do: Macro.underscore(name)

    defp function(parts), do: parts |> IO.iodata_to_binary() |> Identifier.atom!()

    defp static_name(name, suffix) do
      name
      |> rust_identifier()
      |> String.upcase()
      |> Kernel.<>("_#{suffix}")
      |> Identifier.atom!()
    end
  end
end
