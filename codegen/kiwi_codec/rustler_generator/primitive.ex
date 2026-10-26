if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator.Primitive do
    @moduledoc """
    How generated decoders read and skip Kiwi's primitive values with the `Decoder`.

    `defrust_readers/0` and `defrust_skippers/0` define the `kiwi_<type>_value` and
    `kiwi_skip_<type>_value` functions, one per primitive type and one for byte arrays, in the
    RustQ module using them.
    """

    alias KiwiCodec.PrimitiveType
    alias KiwiCodec.RustlerGenerator.Name
    alias RustQ.Rust.AST
    alias RustQ.Rust.AST.Builder, as: A

    @doc "The `decoder.read_*(...)` call reading a primitive value, without `?`."
    @spec read(PrimitiveType.name()) :: AST.expr()
    def read(type) do
      {method, term?} = reader(type)
      A.method(:decoder, method, if(term?, do: [:env], else: []))
    end

    @doc "Defines `kiwi_<type>_value(env, decoder)` for each primitive type and byte arrays."
    defmacro defrust_readers do
      for type <- types() do
        {method, term?} = reader(type)

        body =
          if term?,
            do: quote(do: decoder.unquote(method)(env)),
            else: quote(do: {:ok, decoder.unquote(method)().encode(env)})

        quote do
          @spec unquote(Name.value_function(type))(
                  RustQ.Type.path(:Env, RustQ.Type.lifetime(:a)),
                  RustQ.Type.mut_ref(RustQ.Type.path(:Decoder, RustQ.Type.lifetime(:_)))
                ) :: RustQ.Type.nif_result(term())
          defrust(unquote(Name.value_function(type))(env, decoder), do: unquote(body))
        end
      end
    end

    @doc "Defines `kiwi_skip_<type>_value(decoder)` for each primitive type and byte arrays."
    defmacro defrust_skippers do
      for type <- types() do
        quote do
          @spec unquote(Name.skip_value_function(type))(
                  RustQ.Type.mut_ref(RustQ.Type.path(:Decoder, RustQ.Type.lifetime(:_)))
                ) :: RustQ.Type.nif_result(RustQ.Type.unit())
          defrust unquote(Name.skip_value_function(type))(decoder) do
            decoder.unquote(skipper(type))()
            :ok
          end
        end
      end
    end

    # Byte arrays read and skip as one value, not as repeated bytes.
    defp types, do: PrimitiveType.names() ++ ["bytes"]

    # The method reading a value, and whether it reads it as a term, taking the `env`.
    defp reader("bool"), do: {:read_bool, false}
    defp reader("byte"), do: {:read_byte, false}
    defp reader("int"), do: {:read_var_int, false}
    defp reader("int64"), do: {:read_var_int64, false}
    defp reader("uint"), do: {:read_var_uint, false}
    defp reader("uint64"), do: {:read_var_uint64, false}
    defp reader("float"), do: {:read_var_float, true}
    defp reader("string"), do: {:read_string, true}
    defp reader("bytes"), do: {:read_byte_array, true}

    defp skipper("float"), do: :read_var_float_value
    defp skipper("string"), do: :skip_string
    defp skipper("bytes"), do: :skip_byte_array
    defp skipper(type), do: type |> reader() |> elem(0)
  end
end
