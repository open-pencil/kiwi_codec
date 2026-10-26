if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Sparse.Helpers do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [
        RustQ.Rustler.Term,
        KiwiCodec.RustlerGenerator.AtomCache,
        KiwiCodec.RustlerGenerator.Values,
        KiwiCodec.RustlerGenerator.UnknownFields
      ]

    @moduledoc """
    Sparse decoders: a struct or message decodes as a map of the fields present, keyed by their
    atoms, with `__kiwi_module__` naming its generated Elixir module.

    `kiwi_sparse_struct_decoder!` defines a struct's decoder. A message's comes from
    `KiwiCodec.RustlerGenerator.Sparse.Messages`, or with skip decoders from
    `KiwiCodec.RustlerGenerator.Sparse.SkipMessages`; enums use
    `KiwiCodec.RustlerGenerator.Values`' `kiwi_enum_decoder!`.
    """

    alias RustQ.Type, as: R

    @typedoc "The Rust `KiwiSparseField`: a field's id, key, and how to decode its value."
    @type kiwi_sparse_field :: %{
            required(:id) => R.u32(),
            required(:name) => R.raw(:"&'static str"),
            required(:repeated) => R.bool(),
            required(:decode) => R.path(:KiwiDecodeFn)
          }

    defrustmacro kiwi_sparse_struct_decoder(
                   fn: name(:ident),
                   module: module_name(:literal),
                   fields:
                     repeat do
                       field_id(:literal)
                       field_name(:literal)
                       field_repeated(:literal)
                       field_decode(:ident)
                     end
                 ) do
      @spec name(R.path(:Env, R.lifetime(:a)), R.mut_ref(R.path(:Decoder, R.lifetime(:_)))) ::
              R.nif_result(term())
      defrust name(env, decoder) do
        kiwi_sparse_struct_fields(
          env,
          decoder,
          module_name,
          array([
            repeat fields do
              struct_literal(KiwiSparseField,
                id: field_id,
                name: field_name,
                repeated: field_repeated,
                decode: field_decode
              )
            end
          ])
        )
      end
    end

    @spec kiwi_sparse_struct_fields(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.raw(:"&'static str"),
            R.slice(kiwi_sparse_field())
          ) :: R.nif_result(term())
    defrust kiwi_sparse_struct_fields(env, decoder, module_name, fields) do
      keys = Vec.with_capacity(fields.len() + 1)
      values = Vec.with_capacity(fields.len() + 1)
      kiwi_sparse_module_entry(env, module_name, keys, values)

      for field <- fields do
        keys.push(kiwi_atom(env, field.name).encode(env))
        values.push(kiwi_field_value(env, decoder, field.repeated, field.decode))
      end

      Term.map_from_term_arrays(env, ref(keys), ref(values))
    end

    @spec kiwi_sparse_message_fields(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.raw(:"&'static str"),
            R.str(),
            R.slice(kiwi_sparse_field())
          ) :: R.nif_result(term())
    defrust kiwi_sparse_message_fields(env, decoder, module_name, definition_name, fields) do
      keys = Vec.with_capacity(fields.len() + 1)
      values = Vec.with_capacity(fields.len() + 1)
      kiwi_sparse_module_entry(env, module_name, keys, values)
      kiwi_sparse_message_fields_remaining(env, decoder, definition_name, fields, keys, values)
      Term.map_from_term_arrays(env, ref(keys), ref(values))
    end

    # A message's fields end at field id 0, in any order and each at most once.
    @spec kiwi_sparse_message_fields_remaining(
            R.path(:Env, R.lifetime(:a)),
            R.mut_ref(R.path(:Decoder, R.lifetime(:_))),
            R.str(),
            R.slice(kiwi_sparse_field()),
            R.mut_ref(R.vec(term())),
            R.mut_ref(R.vec(term()))
          ) :: R.nif_result(R.unit())
    defrust kiwi_sparse_message_fields_remaining(
              env,
              decoder,
              definition_name,
              fields,
              keys,
              values
            ) do
      field_id = decoder.read_var_uint()

      if field_id == 0 do
        :ok
      else
        case fields.binary_search_by_key(field_id, fn field -> field.id end) do
          {:ok, index} ->
            field = index(fields, index)
            keys.push(kiwi_atom(env, field.name).encode(env))
            values.push(kiwi_field_value(env, decoder, field.repeated, field.decode))

          {:error, _index} ->
            kiwi_unknown_field(decoder, definition_name, field_id)
        end

        kiwi_sparse_message_fields_remaining(env, decoder, definition_name, fields, keys, values)
      end
    end

    # The `__kiwi_module__` entry naming a sparse map's generated Elixir module.
    @spec kiwi_sparse_module_entry(
            R.path(:Env, R.lifetime(:a)),
            R.raw(:"&'static str"),
            R.mut_ref(R.vec(term())),
            R.mut_ref(R.vec(term()))
          ) :: R.unit()
    defrust kiwi_sparse_module_entry(env, module_name, keys, values) do
      keys.push(kiwi_atom(env, "__kiwi_module__").encode(env))
      values.push(kiwi_atom(env, module_name).encode(env))
    end
  end
end
