defmodule KiwiCodec.RustlerGenerator.DecoderMacro do
  @moduledoc """
  Rusty-Elixir macro support for generated Rustler decoders.

  Entrypoint wrappers are authored with `defnif`. Full schema decoders use the
  same semantic boundary, but intentionally lower to compact Rust macro
  invocations instead of expanded Rust function bodies. This keeps generator
  authoring in Elixir/RustQ while preserving small generated source.
  """

  alias KiwiCodec.RustlerGenerator.FullDecoderHelpers
  alias KiwiCodec.RustlerGenerator.Name
  alias KiwiCodec.RustlerGenerator.RustExpr
  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias KiwiCodec.Schema.{Message, Struct}
  alias RustQ.Rust.Identifier

  @spec enum_decoder(SchemaEnum.t()) :: RustQ.Rust.Fragment.t()
  def enum_decoder(%SchemaEnum{} = definition) do
    FullDecoderHelpers.macro_call(:kiwi_enum_decoder,
      fn: RustExpr.ident(Name.decoder_function(definition.name)),
      env: :env,
      decoder: :decoder,
      variants:
        Enum.map(definition.variants, fn field ->
          [variant_value: field.value, variant_name: Name.field_name(field.name)]
        end)
    )
  end

  @spec struct_decoder(Struct.t(), String.t(), map(), (term(), map() -> iodata())) ::
          RustQ.Rust.Fragment.t()
  def struct_decoder(%Struct{} = definition, module_prefix, definition_map, field_expr_fun) do
    FullDecoderHelpers.macro_call(:kiwi_struct_decoder,
      fn: RustExpr.ident(Name.decoder_function(definition.name)),
      env: :env,
      decoder: :decoder,
      module_static: RustExpr.ident(Name.module_atom_static(definition.name)),
      keys_static: RustExpr.ident(Name.struct_keys_static(definition.name)),
      module: Name.module_name(module_prefix, definition.name),
      keys: key_rows(definition.fields),
      fields: field_expr_rows(definition.fields, definition_map, field_expr_fun)
    )
  end

  @spec message_decoder(Message.t(), String.t(), map(), (term(), map() -> iodata())) ::
          RustQ.Rust.Fragment.t()
  def message_decoder(%Message{} = definition, module_prefix, definition_map, _field_expr_fun) do
    FullDecoderHelpers.macro_call(:kiwi_message_decoder,
      fn: RustExpr.ident(Name.decoder_function(definition.name)),
      fields_fn: RustExpr.ident(Name.message_fields_function(definition.name)),
      env: :env,
      decoder: :decoder,
      module_static: RustExpr.ident(Name.module_atom_static(definition.name)),
      keys_static: RustExpr.ident(Name.struct_keys_static(definition.name)),
      module: Name.module_name(module_prefix, definition.name),
      keys: key_rows(definition.fields),
      fields: message_field_rows(definition.fields, definition_map)
    )
  end

  defmacro entrypoint(nif_name, decoder_name) do
    nif_name = expand_arg!(nif_name, __CALLER__)
    decoder_name = expand_arg!(decoder_name, __CALLER__)

    quote do
      @nif schedule: "DirtyCpu"
      @spec unquote(nif_name)(binary()) :: R.nif_result(term())
      defnif unquote(nif_name)(bytes) do
        decoder = Decoder.new(bytes.as_slice())

        case unquote(decoder_name)(nif_env(), decoder) do
          {:ok, term} ->
            case decoder.finish() do
              {:ok, _done} -> {:ok, term}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defp expand_arg!(quoted, caller) do
    {value, _binding} = Code.eval_quoted(quoted, [], caller)
    value
  end

  defp key_rows(fields) do
    Enum.map(fields, &[key: Name.field_name(&1.name)])
  end

  defp field_expr_rows(fields, definition_map, field_expr_fun) do
    Enum.map(fields, &[field_expr: field_expr_fun.(&1, definition_map)])
  end

  defp message_field_rows(fields, definition_map) do
    fields
    |> Enum.with_index()
    |> Enum.map(fn {field, index} ->
      [
        field_id: field.id,
        field_index: index + 1,
        field_repeated: repeated_field?(field),
        field_decode: full_decode_function(field, definition_map)
      ]
    end)
  end

  defp repeated_field?(%{array?: true, type: "byte"}), do: false
  defp repeated_field?(%{array?: array?}), do: array?

  defp full_decode_function(%{array?: true, type: "byte"}, _definition_map),
    do: :kiwi_full_bytes_value

  defp full_decode_function(%{array?: true} = field, definition_map),
    do: full_decode_function(%{field | array?: false}, definition_map)

  defp full_decode_function(%{type: type}, definition_map) do
    case RustExpr.primitive(type) do
      nil -> Name.decoder_function(Map.fetch!(definition_map, type).name)
      _expr -> Identifier.atom!("kiwi_full_#{RustExpr.ident(type)}_value")
    end
  end
end
