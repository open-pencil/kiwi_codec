defmodule KiwiCodec.RustlerGenerator.Sparse do
  @moduledoc """
  Generates generic sparse Kiwi schema decoders for Rustler native backends.

  Sparse decoders return maps containing only fields present in the payload plus
  a `__kiwi_module__` key identifying the generated Elixir schema module.
  """

  alias KiwiCodec.RustlerGenerator.Name
  alias KiwiCodec.RustlerGenerator.RustExpr
  alias KiwiCodec.RustlerGenerator.SparseHelpers
  alias RustQ.Meta.AST, as: MetaAST
  alias KiwiCodec.Schema.Enum, as: SchemaEnum
  alias KiwiCodec.Schema.{Message, Struct}

  @spec fragments([KiwiCodec.Schema.definition()], String.t(), map(), keyword()) :: [
          RustQ.Rust.Fragment.t()
        ]
  def fragments(definitions, module_prefix, definition_map, opts \\ []) do
    full? = Keyword.get(opts, :full?, false)
    struct_mode = Keyword.get(opts, :struct_mode, :match)
    message_mode = Keyword.get(opts, :message_mode, :match)

    definitions
    |> Enum.flat_map(fn definition ->
      definition(definition, module_prefix, definition_map, full?, struct_mode, message_mode)
      |> List.wrap()
    end)
  end

  defp definition(
         %Struct{name: name, fields: fields},
         module_prefix,
         definition_map,
         _full?,
         :match,
         _message_mode
       ) do
    SparseHelpers.macro_call(:kiwi_sparse_struct_decoder,
      fn: "decode_sparse_#{RustExpr.ident(name)}_from_decoder",
      env: :env,
      decoder: :decoder,
      module: module_name(module_prefix, name),
      capacity: length(fields) + 1,
      fields: Enum.map(fields, &sparse_struct_row(&1, definition_map))
    )
  end

  defp definition(
         %Struct{name: name, fields: fields},
         module_prefix,
         definition_map,
         _full?,
         :descriptor,
         _message_mode
       ) do
    SparseHelpers.macro_call(:kiwi_sparse_struct_decoder,
      fn: "decode_sparse_#{RustExpr.ident(name)}_from_decoder",
      env: :env,
      decoder: :decoder,
      module: module_name(module_prefix, name),
      capacity: length(fields) + 1,
      fields: Enum.map(fields, &sparse_struct_row(&1, definition_map))
    )
  end

  defp definition(
         %SchemaEnum{name: name},
         _module_prefix,
         _definition_map,
         true,
         _struct_mode,
         _message_mode
       ) do
    sparse_enum_passthrough_function(name)
  end

  defp definition(
         %SchemaEnum{name: name, variants: variants},
         _module_prefix,
         _definition_map,
         false,
         _struct_mode,
         _message_mode
       ) do
    SparseHelpers.macro_call(:kiwi_sparse_enum_decoder,
      fn: "decode_sparse_#{RustExpr.ident(name)}_from_decoder",
      env: :env,
      decoder: :decoder,
      variants:
        variants
        |> Enum.sort_by(& &1.value)
        |> Enum.map(&[variant_value: &1.value, variant_name: Macro.underscore(&1.name)])
    )
  end

  defp definition(
         %Message{name: name, fields: fields},
         module_prefix,
         definition_map,
         _full?,
         _struct_mode,
         :match
       ) do
    sparse_message_function(
      name,
      module_name(module_prefix, name),
      fields,
      definition_map
    )
  end

  defp definition(
         %Message{name: name, fields: fields},
         module_prefix,
         definition_map,
         _full?,
         _struct_mode,
         :descriptor_with_skip
       ) do
    SparseHelpers.macro_call(:kiwi_sparse_skip_message_descriptor_decoder,
      sparse_fn: "decode_sparse_#{RustExpr.ident(name)}_from_decoder",
      skip_fn: "skip_#{RustExpr.ident(name)}_from_decoder",
      env: :env,
      decoder: :decoder,
      module: module_name(module_prefix, name),
      definition: name,
      capacity: length(fields) + 1,
      fields:
        fields
        |> Enum.sort_by(& &1.id)
        |> Enum.map(&sparse_skip_descriptor_row(&1, definition_map))
    )
  end

  defp definition(
         %Message{name: name, fields: fields},
         module_prefix,
         definition_map,
         _full?,
         _struct_mode,
         :descriptor
       ) do
    SparseHelpers.macro_call(:kiwi_sparse_message_descriptor_decoder,
      fn: "decode_sparse_#{RustExpr.ident(name)}_from_decoder",
      env: :env,
      decoder: :decoder,
      module: module_name(module_prefix, name),
      definition: name,
      capacity: length(fields) + 1,
      fields:
        fields
        |> Enum.sort_by(& &1.id)
        |> Enum.map(&sparse_message_descriptor_row(&1, definition_map))
    )
  end

  defp sparse_enum_passthrough_function(name) do
    function = sparse_function_name(name)
    module = sparse_enum_passthrough_module!(name)
    module |> MetaAST.items([function]) |> List.first()
  end

  defp sparse_message_function(name, module_name, fields, definition_map) do
    function = sparse_function_name(name)
    module = sparse_message_module!(name, module_name, fields, definition_map)
    module |> MetaAST.items([function]) |> List.first()
  end

  defp sparse_enum_passthrough_module!(name) do
    module =
      Module.concat([
        KiwiCodec.RustlerGenerator.Generated,
        "SparseEnumPassthrough#{:erlang.phash2(name)}"
      ])

    if Code.ensure_loaded?(module) do
      module
    else
      Module.create(module, sparse_enum_passthrough_body(name), Macro.Env.location(__ENV__))
      module
    end
  end

  defp sparse_enum_passthrough_body(name) do
    function = sparse_function_name(name)
    full_function = Name.decoder_function(name)

    quote do
      use RustQ.Meta
      alias RustQ.Type, as: R

      @spec unquote(function)(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust unquote(function)(env, decoder) do
        unquote(full_function)(env, decoder)
      end
    end
  end

  defp sparse_message_module!(name, module_name, fields, definition_map) do
    module =
      Module.concat([
        KiwiCodec.RustlerGenerator.Generated,
        "SparseMessage#{:erlang.phash2({name, module_name, Enum.map(fields, & &1.id)})}"
      ])

    if Code.ensure_loaded?(module) do
      module
    else
      Module.create(
        module,
        sparse_message_module_body(name, module_name, fields, definition_map),
        Macro.Env.location(__ENV__)
      )

      module
    end
  end

  defp sparse_message_module_body(name, module_name, fields, definition_map) do
    sparse_message_body(name, module_name, fields, definition_map)
  end

  defp sparse_message_body(name, module_name, fields, definition_map) do
    function = sparse_function_name(name)

    entries =
      Enum.map(Enum.sort_by(fields, & &1.id), &sparse_message_field_entry(&1, definition_map))

    capacity = length(fields) + 1

    quote do
      use RustQ.Meta
      alias RustQ.Type, as: R

      @spec unquote(function)(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust unquote(function)(env, decoder) do
        kiwi_sparse_message_fields(
          env,
          decoder,
          unquote(module_name),
          unquote(name),
          unquote(capacity),
          ref(array([unquote_splicing(entries)]))
        )
      end
    end
  end

  defp sparse_message_field_entry(field, definition_map) do
    quote do
      struct_literal(KiwiSparseField,
        id: unquote(field.id),
        name: unquote(Macro.underscore(field.name)),
        repeated: unquote(sparse_repeated?(field)),
        decode: unquote(Macro.var(sparse_decode_function(field, definition_map), nil))
      )
    end
  end

  defp sparse_repeated?(%{array?: true, type: "byte"}), do: false
  defp sparse_repeated?(%{array?: array?}), do: array?

  defp sparse_decode_function(%{array?: true, type: "byte"}, _definition_map),
    do: :kiwi_sparse_bytes_value

  defp sparse_decode_function(%{array?: true} = field, definition_map),
    do: sparse_decode_function(%{field | array?: false}, definition_map)

  defp sparse_decode_function(field, definition_map),
    do:
      field
      |> descriptor_scalar_function(definition_map)
      |> IO.iodata_to_binary()
      |> String.to_atom()

  defp sparse_struct_row(field, definition_map) do
    [
      field_name: Macro.underscore(field.name),
      field_repeated: sparse_repeated?(field),
      field_decode: sparse_decode_function(field, definition_map)
    ]
  end

  defp sparse_message_descriptor_row(field, definition_map) do
    [
      field_id: field.id,
      field_name: Macro.underscore(field.name),
      field_repeated: sparse_repeated?(field),
      field_decode: sparse_decode_function(field, definition_map)
    ]
  end

  defp sparse_skip_descriptor_row(field, definition_map) do
    {skip_repeated?, skip_bytes?, skip} = skip_descriptor(field, definition_map)

    [
      field_id: field.id,
      field_name: Name.field_name(field.name),
      field_repeated: sparse_repeated?(field),
      field_decode: sparse_decode_function(field, definition_map),
      field_skip_repeated: skip_repeated?,
      field_skip_bytes: skip_bytes?,
      field_skip: skip
    ]
  end

  defp skip_descriptor(%{array?: true, type: "byte"}, _definition_map),
    do: {false, true, :kiwi_skip_bytes_value}

  defp skip_descriptor(%{array?: true} = field, definition_map) do
    {_repeated?, _bytes?, skip} = skip_descriptor(%{field | array?: false}, definition_map)
    {true, false, skip}
  end

  defp skip_descriptor(%{type: type}, definition_map) do
    skip =
      cond do
        KiwiCodec.PrimitiveType.name?(type) ->
          RustQ.Atom.identifier!("kiwi_skip_#{RustExpr.ident(type)}_value")

        match?(%SchemaEnum{}, Map.get(definition_map, type)) ->
          :kiwi_skip_uint_value

        Map.has_key?(definition_map, type) ->
          RustQ.Atom.identifier!("skip_#{RustExpr.ident(type)}_from_decoder")
      end

    {false, false, skip}
  end

  defp sparse_function_name(name),
    do: String.to_atom("decode_sparse_#{RustExpr.ident(name)}_from_decoder")

  defp descriptor_scalar_function(%{type: type}, definition_map) do
    cond do
      KiwiCodec.PrimitiveType.name?(type) ->
        ["kiwi_sparse_", RustExpr.ident(type), "_value"]

      Map.has_key?(definition_map, type) ->
        ["decode_sparse_", RustExpr.ident(type), "_from_decoder"]
    end
  end

  defp module_name(module_prefix, name), do: "Elixir.#{module_prefix}.#{name}"
end
