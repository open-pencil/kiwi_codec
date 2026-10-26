if Code.ensure_loaded?(RustQ) do
  defmodule KiwiCodec.RustlerGenerator do
    @moduledoc """
    Generates Rust that decodes Kiwi data for a schema inside a Rustler NIF.

    `source/2` returns a complete Rust source file: decoders for the schema's
    definitions, the helpers they share, and NIF entrypoints. Call it from
    `rustq.exs`, where `mix rustq.gen` writes the file and `mix rustq.gen --check`
    keeps it fresh. The crate provides the `Decoder<'a>` the generated code reads
    with; `KiwiCodec.RustlerGenerator.Decoder` describes it and ships a complete
    one.

    The generator needs RustQ, an optional dependency, and exists only where RustQ
    is available. [Native decoders](native-decoders.md) covers each feature.
    """

    alias KiwiCodec.RustlerGenerator.Entrypoint
    alias KiwiCodec.RustlerGenerator.Full
    alias KiwiCodec.RustlerGenerator.Records
    alias KiwiCodec.RustlerGenerator.Selection
    alias KiwiCodec.RustlerGenerator.Skip
    alias KiwiCodec.RustlerGenerator.Sparse
    alias KiwiCodec.RustlerGenerator.Splice
    alias KiwiCodec.Schema
    alias RustQ.Rust
    alias RustQ.Rust.AST.Builder, as: A

    @type entrypoint :: {atom() | String.t(), String.t()}

    @doc """
    Returns a complete Rust source file for generated Rustler decoders.

        generate :native_decoders, "native/my_nif/src/generated.rs" do
          schema = KiwiCodec.parse_schema!(File.read!("priv/schema.kiwi"))

          content KiwiCodec.RustlerGenerator.source(schema,
            entrypoints: ["Node"],
            module_prefix: "Example.Schema"
          )
        end

    Options:

      * `:definitions` - schema definition names to generate, including their
        dependencies. Defaults to the requested entrypoint definitions, or all
        definitions when no entrypoints are requested.
      * `:entrypoints` - `:all`, `{:nif_stubs, module}`, a NIF stub module,
        definition names, or `{nif_name, definition_name}` entries for generated
        NIFs. Definition names infer `decode_<definition_name>` NIFs. `:all`
        generates one inferred NIF for every schema definition. A NIF stub module
        infers entries from one-arity `decode_*` stubs whose suffix matches a schema
        definition. For `{:nif_stubs, module}`, the module must expose `stubs/0`.
      * `:module_prefix` - Elixir module prefix for decoded structs.
      * `:decoder` - Rust path imported as `Decoder`. Defaults to
        `"crate::runtime::Decoder"`. Its methods have the signatures
        `KiwiCodec.RustlerGenerator.Decoder` lists.
      * `:features` - decoder families to generate. Defaults to `[:full]`.
        Use `:sparse` and `:skip` for generic sparse map decoders and skip
        helpers used by projection-oriented native backends, and `:records` for
        native records Rust code can work with before encoding them; see
        `KiwiCodec.RustlerGenerator.Records`.
      * `:unknown_fields` - how message decoders handle fields the schema does
        not define: `:error` (default) rejects the data; `:runtime_schema` skips
        them using a schema read with the data. See
        `KiwiCodec.RustlerGenerator.UnknownFields` for the `Decoder` contract.

    """
    @spec source(Schema.t(), keyword()) :: String.t()
    def source(%Schema{} = schema, opts) do
      opts =
        Keyword.validate!(opts, [
          :definitions,
          :module_prefix,
          entrypoints: [],
          decoder: "crate::runtime::Decoder",
          features: [:full],
          unknown_fields: :error
        ])

      [source_prelude(opts), generated_fragments(schema, opts)]
      |> List.flatten()
      |> Enum.map_join("\n\n", &Rust.to_fragment/1)
      |> Kernel.<>("\n")
    end

    defp generated_fragments(%Schema{} = schema, opts) do
      entrypoints = normalize_entrypoints(opts[:entrypoints], schema)
      definitions = opts[:definitions] || inferred_definitions(entrypoints)
      module_prefix = Keyword.fetch!(opts, :module_prefix)

      definition_map = Selection.definition_map(schema)
      selected = Selection.definitions(schema, definitions, definition_map)

      [
        Splice.rustler_helpers(opts),
        feature_fragments(opts[:features], selected, module_prefix, definition_map),
        Entrypoint.fragments(entrypoints)
      ]
    end

    defp feature_fragments(features, selected, module_prefix, definition_map) do
      Enum.flat_map(features, fn
        :full -> Full.fragments(selected, module_prefix, definition_map)
        :sparse -> Sparse.fragments(selected, module_prefix, definition_map, :skip in features)
        :skip -> Skip.fragments(selected, definition_map, :sparse in features)
        :records -> Records.fragments(selected, module_prefix)
        feature -> raise ArgumentError, "unknown Rustler generator feature #{inspect(feature)}"
      end)
    end

    defp normalize_entrypoints(:all, %Schema{} = schema) do
      schema.definitions
      |> Enum.map(& &1.name)
      |> normalize_entrypoints(schema)
    end

    defp normalize_entrypoints({:nif_stubs, module}, %Schema{} = schema) when is_atom(module) do
      Code.ensure_loaded!(module)

      unless function_exported?(module, :stubs, 0) do
        raise ArgumentError, "expected #{inspect(module)} to expose stubs/0"
      end

      module.stubs() |> entrypoints_from_exports(schema)
    end

    defp normalize_entrypoints(module, %Schema{} = schema) when is_atom(module) do
      Code.ensure_loaded!(module)
      module.module_info(:exports) |> entrypoints_from_exports(schema)
    end

    defp normalize_entrypoints(entrypoints, %Schema{}) do
      Enum.map(entrypoints, fn
        {nif_name, definition_name} -> {nif_name, to_string(definition_name)}
        definition_name -> {inferred_entrypoint_name(definition_name), to_string(definition_name)}
      end)
    end

    defp entrypoints_from_exports(exports, %Schema{} = schema) do
      definitions_by_underscore =
        Map.new(schema.definitions, &{Macro.underscore(&1.name), &1.name})

      exports
      |> Enum.flat_map(fn
        {name, 1} -> entrypoint_from_export(name, definitions_by_underscore)
        _export -> []
      end)
      |> Enum.sort_by(fn {nif_name, _definition_name} -> to_string(nif_name) end)
    end

    defp entrypoint_from_export(name, definitions_by_underscore) do
      name = to_string(name)

      with "decode_" <> suffix <- name,
           {:ok, definition_name} <- Map.fetch(definitions_by_underscore, suffix) do
        [{name, definition_name}]
      else
        _other -> []
      end
    end

    defp inferred_entrypoint_name(definition_name) do
      definition_name
      |> to_string()
      |> Macro.underscore()
      |> then(&"decode_#{&1}")
    end

    defp inferred_definitions([]), do: []

    defp inferred_definitions(entrypoints) do
      Enum.map(entrypoints, fn {_nif_name, definition_name} -> definition_name end)
    end

    defp source_prelude(opts) do
      [
        A.use([:rustler, :types, :atom, :Atom]),
        A.use({[:rustler], [:Binary, :Encoder, :Env, :Error, :NifResult, :Term]}),
        A.use({[:std, :sync], [:OnceLock]}),
        A.use(opts[:decoder])
      ]
    end
  end
end
