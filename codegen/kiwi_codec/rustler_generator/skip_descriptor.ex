defmodule KiwiCodec.RustlerGenerator.SkipDescriptor do
  @moduledoc false

  alias KiwiCodec.RustlerGenerator.RustExpr
  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias RustQ.Rust.Identifier

  @spec scalar_function(String.t(), map()) :: atom()
  def scalar_function(type, definition_map) do
    cond do
      KiwiCodec.PrimitiveType.name?(type) ->
        Identifier.atom!("kiwi_skip_#{RustExpr.ident(type)}_value")

      match?(%SchemaEnum{}, Map.get(definition_map, type)) ->
        :kiwi_skip_uint_value

      Map.has_key?(definition_map, type) ->
        Identifier.atom!("skip_#{RustExpr.ident(type)}_from_decoder")
    end
  end
end
