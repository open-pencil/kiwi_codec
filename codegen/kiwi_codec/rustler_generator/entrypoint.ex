if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Entrypoint do
    use RustQ.Meta,
      rust_sources: [KiwiCodec.RustlerGenerator.Decoder.source()],
      callable_modules: [KiwiCodec.RustlerGenerator.Values]

    @moduledoc """
    Generates NIFs decoding a binary as one definition, which `kiwi_decode_binary` does with
    the definition's full decoder, rejecting trailing bytes.
    """

    require RustQ.Rust.AST.ItemBuilder, as: I

    alias KiwiCodec.RustlerGenerator.Name
    alias RustQ.Rust.AST.Builder, as: A
    alias RustQ.Type, as: R

    @doc "`kiwi_decode_binary`, and a NIF for each `{nif_name, definition_name}`."
    @spec fragments([{atom() | String.t(), String.t()}]) :: [RustQ.Rust.Fragment.t()]
    def fragments([]), do: []
    def fragments(entrypoints), do: __rustq_items__() ++ Enum.map(entrypoints, &nif/1)

    defp nif({nif_name, definition_name}) do
      I.function nif_name,
        args: [env: "Env<'a>", bytes: "Binary"],
        returns: "NifResult<Term<'a>>",
        lifetimes: [:a],
        attrs: [A.nif_attr(schedule: "DirtyCpu")] do
        A.return_stmt(
          A.call(:kiwi_decode_binary, [
            :env,
            :bytes,
            A.path(Name.decoder_function(definition_name))
          ])
        )
      end
    end

    @spec kiwi_decode_binary(
            R.path(:Env, R.lifetime(:a)),
            R.path(:Binary),
            R.path(:KiwiDecodeFn)
          ) :: R.nif_result(term())
    defrust kiwi_decode_binary(env, bytes, decode) do
      decoder = Decoder.new(bytes.as_slice())

      case decode(env, mut_ref(decoder)) do
        {:ok, term} ->
          decoder.finish()
          {:ok, term}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
