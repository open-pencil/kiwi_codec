defmodule KiwiCodec.RustlerGenerator.DecoderMacro do
  @moduledoc """
  Rusty-Elixir macro support for generated Rustler NIF entrypoints.

  Schema-specific decoder bodies are emitted through compact Rust macro
  invocations. The entrypoint wrapper remains authored with `defrust` so NIF
  boundary control flow stays in Rusty-Elixir instead of raw Rust source.
  """

  defmacro entrypoint(nif_name, decoder_name) do
    nif_name = expand_arg!(nif_name, __CALLER__)
    decoder_name = expand_arg!(decoder_name, __CALLER__)

    quote do
      @nif schedule: "DirtyCpu"
      @spec unquote(nif_name)(R.path(:Env, R.lifetime(:a)), R.path(:Binary, R.lifetime(:a))) ::
              R.nif_result(R.path(:Term, R.lifetime(:a)))
      defrust unquote(nif_name)(env, bytes) do
        decoder = Decoder.new(bytes.as_slice())

        case unquote(decoder_name)(env, mut_ref(decoder)) do
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
end
