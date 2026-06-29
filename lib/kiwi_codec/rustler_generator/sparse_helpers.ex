defmodule KiwiCodec.RustlerGenerator.SparseHelpers do
  @moduledoc """
  Builds RustQ-authored shared sparse helper functions for generated Rustler decoders.

  These helpers are used when callers provide `:decoder_sources`, allowing
  RustQ to read the downstream `Decoder` implementation and infer fallible
  method propagation from real Rust metadata.
  """

  alias RustQ.Meta.AST, as: MetaAST

  @functions [
    :kiwi_sparse_bool_value,
    :kiwi_sparse_byte_value,
    :kiwi_sparse_float_value,
    :kiwi_sparse_int_value,
    :kiwi_sparse_int64_value,
    :kiwi_sparse_string_value,
    :kiwi_sparse_uint_value,
    :kiwi_sparse_uint64_value,
    :kiwi_sparse_bytes_value
  ]

  @spec fragments([Path.t()] | Path.t()) :: [RustQ.Rust.Fragment.t()]
  def fragments(decoder_sources) do
    decoder_sources
    |> generated_module!()
    |> MetaAST.items(@functions)
  end

  defp generated_module!(decoder_sources) do
    decoder_sources = List.wrap(decoder_sources)

    module =
      Module.concat([
        KiwiCodec.RustlerGenerator.Generated,
        "SparseHelpers#{:erlang.phash2(decoder_sources)}"
      ])

    if Code.ensure_loaded?(module) do
      module
    else
      Module.create(module, quoted_module(decoder_sources), Macro.Env.location(__ENV__))
      module
    end
  end

  defp quoted_module(decoder_sources) do
    quote do
      use RustQ.Meta, rust_sources: unquote(decoder_sources)

      alias RustQ.Type, as: R

      @spec kiwi_sparse_bool_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_bool_value(env, decoder) do
        value = unwrap!(decoder.read_bool())
        {:ok, value.encode(env)}
      end

      @spec kiwi_sparse_byte_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_byte_value(env, decoder) do
        value = unwrap!(decoder.read_byte())
        {:ok, value.encode(env)}
      end

      @spec kiwi_sparse_float_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_float_value(env, decoder) do
        decoder.read_var_float(env)
      end

      @spec kiwi_sparse_int_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_int_value(env, decoder) do
        value = unwrap!(decoder.read_var_int())
        {:ok, value.encode(env)}
      end

      @spec kiwi_sparse_int64_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_int64_value(env, decoder) do
        value = unwrap!(decoder.read_var_int64())
        {:ok, value.encode(env)}
      end

      @spec kiwi_sparse_string_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_string_value(env, decoder) do
        decoder.read_string(env)
      end

      @spec kiwi_sparse_uint_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_uint_value(env, decoder) do
        value = unwrap!(decoder.read_var_uint())
        {:ok, value.encode(env)}
      end

      @spec kiwi_sparse_uint64_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_uint64_value(env, decoder) do
        value = unwrap!(decoder.read_var_uint64())
        {:ok, value.encode(env)}
      end

      @spec kiwi_sparse_bytes_value(
              R.path(:Env, R.lifetime(:a)),
              R.mut_ref(R.path(:Decoder, R.lifetime(:_)))
            ) :: R.nif_result(term())
      defrust kiwi_sparse_bytes_value(env, decoder) do
        decoder.read_byte_array(env)
      end
    end
  end
end
