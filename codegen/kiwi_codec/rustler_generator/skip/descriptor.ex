defmodule KiwiCodec.RustlerGenerator.Skip.Descriptor do
  @moduledoc """
  Names the Rust function that skips one value of a Kiwi type: a primitive's
  shared skip helper, `kiwi_skip_uint_value` for an enum, or the generated
  `skip_<definition>_from_decoder` for a struct or message.
  """

  alias KiwiCodec.RustlerGenerator.RustExpr
  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias RustQ.Rust.Identifier

  @doc "Returns the skip function for `type`, given the schema's definitions by name."
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
