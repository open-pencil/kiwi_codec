defmodule KiwiCodec.RustlerGenerator.FullDecoderHelpers do
  use RustQ.Meta,
    callable_modules: [RustQ.Rustler.Atom, RustQ.Rustler.Term]

  @moduledoc """
  RustQ-authored full Kiwi decoder macro helpers.
  """

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Type, as: R

  @macros [
    :kiwi_enum_decoder,
    :kiwi_struct_decoder,
    :kiwi_message_decoder
  ]

  @functions [
    :kiwi_enum_value,
    :kiwi_full_bool_value,
    :kiwi_full_byte_value,
    :kiwi_full_float_value,
    :kiwi_full_int_value,
    :kiwi_full_int64_value,
    :kiwi_full_string_value,
    :kiwi_full_uint_value,
    :kiwi_full_uint64_value,
    :kiwi_full_bytes_value,
    :kiwi_message_fields,
    :kiwi_full_field_value
  ]

  @type kiwi_full_decode_fn ::
          R.raw(:"for<'a> fn(Env<'a>, &mut Decoder<'_>) -> NifResult<Term<'a>>")

  @type kiwi_full_field :: %{
          required(:id) => R.u32(),
          required(:index) => R.usize(),
          required(:repeated) => R.bool(),
          required(:decode) => kiwi_full_decode_fn()
        }

  @type kiwi_enum_variant :: %{
          required(:value) => R.u32(),
          required(:name) => R.str()
        }

  @spec fragments([atom()]) :: [RustQ.Rust.Fragment.t()]
  def fragments(macros \\ @macros) do
    __MODULE__.__rustq_type_items__() ++
      MetaAST.macro_items(__MODULE__, macros) ++ MetaAST.items(__MODULE__, @functions)
  end

  @spec macro_call(atom(), keyword()) :: RustQ.Rust.Fragment.t()
  def macro_call(name, args), do: MetaAST.macro_call(__MODULE__, name, args)

  defrustmacro kiwi_struct_decoder(
                 fn: name(:ident),
                 env: env(:ident),
                 decoder: decoder(:ident),
                 module_static: module_static(:ident),
                 keys_static: keys_static(:ident),
                 module: module_name(:literal),
                 keys:
                   repeat do
                     key(:literal)
                   end,
                 fields:
                   repeat do
                     field_expr(:expr)
                   end
               ) do
    @spec name(R.path(:Env, R.lifetime(:a)), R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
            R.nif_result(term())
    defrust name(env, decoder) do
      module_atom = cached_atom(env, ref(module_static), module_name)

      keys =
        cached_struct_keys(
          env,
          ref(keys_static),
          ref(
            array([
              repeat keys do
                key
              end
            ])
          )
        )

      make_struct_from_nif_term_arrays(
        env,
        keys,
        ref(
          array([
            module_atom.as_c_arg(),
            repeat fields do
              field_expr.encode(env).as_c_arg()
            end
          ])
        )
      )
    end
  end

  defrustmacro kiwi_message_decoder(
                 fn: decoder_name(:ident),
                 fields_fn: fields_name(:ident),
                 env: env(:ident),
                 decoder: decoder(:ident),
                 module_static: module_static(:ident),
                 keys_static: keys_static(:ident),
                 module: module_name(:literal),
                 keys:
                   repeat do
                     key(:literal)
                   end,
                 fields:
                   repeat do
                     field_id(:literal)
                     field_index(:literal)
                     field_repeated(:literal)
                     field_decode(:ident)
                   end
               ) do
    @spec decoder_name(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
          ) :: R.nif_result(term())
    defrust decoder_name(env, decoder) do
      module_atom = cached_atom(env, ref(module_static), module_name)

      keys =
        cached_struct_keys(
          env,
          ref(keys_static),
          ref(
            array([
              repeat keys do
                key
              end
            ])
          )
        )

      values = default_struct_values(env, module_atom, keys.len() - 1)
      fields_name(env, decoder, keys, values)
    end

    @spec fields_name(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.slice(R.path({:rustler, :wrapper, :NIF_TERM})),
            R.vec(R.path({:rustler, :wrapper, :NIF_TERM}))
          ) :: R.nif_result(term())
    defrust fields_name(env, decoder, struct_keys, struct_values) do
      kiwi_message_fields(
        env,
        decoder,
        struct_keys,
        struct_values,
        ref(
          array([
            repeat fields do
              struct_literal(KiwiFullField,
                id: field_id,
                index: field_index,
                repeated: field_repeated,
                decode: field_decode
              )
            end
          ])
        )
      )
    end
  end

  defrustmacro kiwi_enum_decoder(
                 fn: name(:ident),
                 env: env(:ident),
                 decoder: decoder(:ident),
                 variants:
                   repeat do
                     variant_value(:literal)
                     variant_name(:literal)
                   end
               ) do
    @spec name(R.path(:Env, R.lifetime(:a)), R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
            R.nif_result(term())
    defrust name(env, decoder) do
      kiwi_enum_value(
        env,
        decoder,
        ref(
          array([
            repeat variants do
              struct_literal(KiwiEnumVariant,
                value: variant_value,
                name: variant_name
              )
            end
          ])
        )
      )
    end
  end

  @spec kiwi_full_bool_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_bool_value(env, decoder) do
    value = decoder.read_bool()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_byte_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_byte_value(env, decoder) do
    value = decoder.read_byte()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_float_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_float_value(env, decoder) do
    value = decoder.read_var_float_value()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_int_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_int_value(env, decoder) do
    value = decoder.read_var_int()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_int64_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_int64_value(env, decoder) do
    value = decoder.read_var_int64()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_string_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_string_value(env, decoder) do
    value = decoder.read_string()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_uint_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_uint_value(env, decoder) do
    value = decoder.read_var_uint()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_uint64_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_uint64_value(env, decoder) do
    value = decoder.read_var_uint64()
    {:ok, value.encode(env)}
  end

  @spec kiwi_full_bytes_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
        ) :: R.nif_result(term())
  defrust kiwi_full_bytes_value(env, decoder) do
    decoder.read_byte_array(env)
  end

  @spec kiwi_message_fields(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
          R.slice(R.path({:rustler, :wrapper, :NIF_TERM})),
          R.vec(R.path({:rustler, :wrapper, :NIF_TERM})),
          R.slice(R.path(:KiwiFullField))
        ) :: R.nif_result(term())
  defrust kiwi_message_fields(env, decoder, keys, values, fields) do
    field_id = decoder.read_var_uint()

    if field_id == 0 do
      make_struct_from_nif_term_arrays(env, keys, ref(values))
    else
      case fields.binary_search_by_key(field_id, fn field -> field.id end) do
        {:ok, index} ->
          field = fields.get(index).unwrap()
          value = kiwi_full_field_value(env, decoder, field)
          next_values = values
          assign!(index(next_values, field.index), value.as_c_arg())
          kiwi_message_fields(env, decoder, keys, next_values, fields)

        {:error, _index} ->
          {:error, badarg()}
      end
    end
  end

  @spec kiwi_full_field_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
          R.ref(R.path(:KiwiFullField))
        ) :: R.nif_result(term())
  defrust kiwi_full_field_value(env, decoder, field) do
    if field.repeated do
      values = decoder.read_repeated(fn decoder -> field.decode(env, decoder) end)
      {:ok, values.encode(env)}
    else
      field.decode(env, decoder)
    end
  end

  @spec kiwi_enum_value(
          R.path(:Env, R.lifetime(:a)),
          R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
          R.slice(R.path(:KiwiEnumVariant))
        ) :: R.nif_result(term())
  defrust kiwi_enum_value(env, decoder, variants) do
    value = decoder.read_var_uint()

    case variants.binary_search_by_key(value, fn variant -> variant.value end) do
      {:ok, index} ->
        variant = variants.get(index).unwrap()
        {:ok, Atom.from_str(env, variant.name).unwrap().encode(env)}

      {:error, _index} ->
        {:ok, value.encode(env)}
    end
  end
end
