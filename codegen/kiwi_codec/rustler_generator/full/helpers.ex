if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Full.Helpers do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [
        RustQ.Rustler.Atom,
        RustQ.Rustler.Term,
        KiwiCodec.RustlerGenerator.Values,
        KiwiCodec.RustlerGenerator.UnknownFields
      ]

    @moduledoc """
    Full decoders: a struct or message decodes as its generated Elixir struct, every field
    set. `kiwi_struct_decoder!` and `kiwi_message_decoder!` define one; enums use
    `KiwiCodec.RustlerGenerator.Values`' `kiwi_enum_decoder!`.
    """

    alias RustQ.Type, as: R

    @typedoc """
    The Rust `KiwiFullField`: a message field id, its index among the struct's values, and how to
    decode it.
    """
    @type kiwi_full_field :: %{
            required(:id) => R.u32(),
            required(:index) => R.usize(),
            required(:repeated) => boolean(),
            required(:decode) => R.path(:KiwiDecodeFn)
          }

    # The struct's field expressions read with the caller's `env` and `decoder`, which the
    # macro's own names could not reach.
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

        make_struct_from_arrays(
          env,
          keys,
          ref(
            array([
              module_atom.to_term(env),
              repeat fields do
                field_expr.encode(env)
              end
            ])
          )
        )
      end
    end

    defrustmacro kiwi_message_decoder(
                   fn: decoder_name(:ident),
                   fields_fn: fields_name(:ident),
                   module_static: module_static(:ident),
                   keys_static: keys_static(:ident),
                   module: module_name(:literal),
                   definition: definition_name(:literal),
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
              R.slice(R.path(:Atom)),
              R.vec(term())
            ) :: R.nif_result(term())
      defrust fields_name(env, decoder, struct_keys, struct_values) do
        kiwi_message_fields(
          env,
          decoder,
          definition_name,
          struct_keys,
          struct_values,
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
      end
    end

    @spec kiwi_message_fields(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.str(),
            R.slice(R.path(:Atom)),
            R.vec(term()),
            R.slice(R.path(:KiwiFullField))
          ) :: R.nif_result(term())
    defrust kiwi_message_fields(env, decoder, definition_name, keys, values, fields) do
      field_id = decoder.read_var_uint()

      if field_id == 0 do
        make_struct_from_arrays(env, keys, ref(values))
      else
        case fields.binary_search_by_key(field_id, fn field -> field.id end) do
          {:ok, index} ->
            field = fields.get(index).unwrap()

            assign!(
              index(values, field.index),
              kiwi_field_value(env, decoder, field.repeated, field.decode)
            )

            kiwi_message_fields(env, decoder, definition_name, keys, values, fields)

          {:error, _index} ->
            kiwi_unknown_field(decoder, definition_name, field_id)
            kiwi_message_fields(env, decoder, definition_name, keys, values, fields)
        end
      end
    end
  end
end
