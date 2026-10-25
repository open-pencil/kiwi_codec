defmodule KiwiCodec.RustlerGeneratorTest do
  # What the generated Rust does is tested by building it, in NativeTest below; these tests
  # cover which items the options select.
  use ExUnit.Case, async: true

  alias KiwiCodec.RustlerGenerator

  @schema_source """
  enum Kind { RECTANGLE = 1; }
  struct Point { float x; float y; }
  struct Node { Kind kind; Point position; }
  message Image { byte[] hash = 1; Node node = 2; }
  message Message { Node node = 1; }
  """

  @schema KiwiCodec.parse_schema!(@schema_source)

  defmodule NativeStubs do
    @moduledoc "NIF stubs the generator infers entrypoints from."

    def decode_image(_binary), do: :erlang.nif_error(:nif_not_loaded)
    def decode_node(_binary), do: :erlang.nif_error(:nif_not_loaded)
    def decode_sparse_message(_binary), do: :erlang.nif_error(:nif_not_loaded)
  end

  defmodule NativeStubMetadata do
    @moduledoc "NIF stub metadata the generator infers entrypoints from."

    def stubs, do: [decode_node: 1, decode_image: 1, decode_sparse_message: 1]
  end

  test "writes its source through rustq.gen, which then finds it fresh" do
    dir = Path.join(System.tmp_dir!(), "kiwi-rustq-gen-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    out = Path.join(dir, "generated.rs")
    config = Path.join(dir, "rustq.exs")

    File.write!(config, """
    use RustQ.Config

    schema = KiwiCodec.parse_schema!(#{inspect(@schema_source)})

    generate :generated, #{inspect(out)} do
      content KiwiCodec.RustlerGenerator.source(schema, entrypoints: ["Image"], module_prefix: "Example")
    end
    """)

    for args <- [["--config", config], ["--check", "--config", config]] do
      Mix.Task.reenable("rustq.gen")
      Mix.Task.run("rustq.gen", args)
    end

    assert "decode_image" in functions(File.read!(out))
  end

  test "infers entrypoints from definition names, NIF stubs, or every definition" do
    for {entrypoints, nifs} <- [
          {["Node", "Image"], ~w(decode_image decode_node)},
          {[decode_picture: "Image"], ~w(decode_picture)},
          {NativeStubs, ~w(decode_image decode_node)},
          {{:nif_stubs, NativeStubMetadata}, ~w(decode_image decode_node)},
          {:all, ~w(decode_image decode_kind decode_message decode_node decode_point)}
        ] do
      source =
        RustlerGenerator.source(@schema, entrypoints: entrypoints, module_prefix: "Example")

      assert {entrypoints, Enum.filter(functions(source), &(&1 in all_nifs()))} ==
               {entrypoints, nifs}
    end
  end

  test "reads which Decoder methods are fallible from the decoder sources" do
    source =
      RustlerGenerator.source(KiwiCodec.parse_schema!("message A { int64 offset = 1; }"),
        definitions: ["A"],
        features: [:skip],
        module_prefix: "Example",
        decoder_sources: ["test/fixtures/infallible_decoder.rs"]
      )

    assert source =~ "decoder.read_var_int64();"
    assert source =~ "decoder.read_var_uint()?;"
  end

  test "rejects unknown features and unknown-fields modes" do
    for {opts, message} <- [
          {[features: [:compact]], ~r/unknown Rustler generator feature :compact/},
          {[unknown_fields: :ignore], ~r/expected :unknown_fields/}
        ] do
      assert_raise ArgumentError, message, fn ->
        RustlerGenerator.source(@schema, [module_prefix: "Example"] ++ opts)
      end
    end
  end

  defp all_nifs,
    do: ~w(decode_image decode_kind decode_message decode_node decode_point decode_picture)

  defp functions(source) do
    source |> RustQ.Syn.parse!() |> RustQ.Syn.functions() |> Enum.map(& &1.name) |> Enum.sort()
  end
end

defmodule KiwiCodec.RustlerGenerator.NativeTest do
  # Builds the generated decoders with a real `Decoder` and checks what they return against
  # the Elixir decoder, so the tests judge behavior rather than the shape of the source.
  use ExUnit.Case, async: false

  alias KiwiCodec.RustlerGenerator
  alias KiwiCodec.Schema.Binary
  alias KiwiCodec.SchemaInterpreter
  alias KiwiCodec.Test.NativeCrate

  @moduletag timeout: 600_000

  @prefix "KiwiCodec.NativeTest.Schema"
  @runtime KiwiCodec.RustlerGenerator.Decoder.source()

  @schema """
  enum Kind {
    RECTANGLE = 1;
    ELLIPSE = 2;
    TYPE = 3;
  }

  struct Point {
    float x;
    float y;
  }

  message Child {
    uint id = 1;
    string label = 2;
  }

  message Type {
    uint gen = 1;
    Kind match = 2;
  }

  message Node {
    string name = 1;
    Kind kind = 2;
    Point origin = 3;
    Child[] children = 4;
    byte[] data = 5;
    bool visible = 6;
    int delta = 7;
    uint64 big = 8;
    int64 negative = 9;
    float[] weights = 10;
    byte flag = 11;
    Kind[] kinds = 12;
    string[] tags = 13;
    Type type = 14;
  }
  """

  # A newer schema the data may have been written with: Node gains fields the compiled
  # schema lacks, one of them a message type it has never seen.
  @written_schema String.replace(@schema, "  Type type = 14;\n}", """
                    Type type = 14;
                    uint added = 15;
                    Extra[] extras = 16;
                  }

                  message Extra {
                    string note = 1;
                    Point at = 2;
                  }
                  """)

  @definitions ~w(Kind Point Child Type Node)

  @node %{
    "name" => "frame",
    "kind" => "ELLIPSE",
    "origin" => %{"x" => 1.5, "y" => -2.0},
    "children" => [%{"id" => 7, "label" => "first"}, %{"id" => 8}],
    "data" => <<1, 2, 3>>,
    "visible" => true,
    "delta" => -42,
    "big" => 18_446_744_073_709_551_615,
    "negative" => -9_223_372_036_854_775_808,
    "weights" => [0.25, :infinity],
    "flag" => 255,
    "kinds" => ["RECTANGLE", "TYPE"],
    "tags" => ["a", ""],
    "type" => %{"gen" => 2, "match" => "TYPE"}
  }

  setup_all do
    schema = KiwiCodec.parse_schema!(@schema)
    KiwiCodec.ModuleCompiler.compile_string!(@schema, module_prefix: @prefix)

    NativeCrate.build!([
      crate(
        "kiwi_full",
        __MODULE__.Full,
        schema,
        [features: [:full], entrypoints: :all],
        "",
        for(name <- @definitions, do: {:"decode_#{Macro.underscore(name)}", 1})
      ),
      wrapped_crate("kiwi_sparse_skip", __MODULE__.SparseSkip, schema,
        features: [:sparse, :skip]
      ),
      wrapped_crate("kiwi_descriptor", __MODULE__.Descriptor, schema,
        features: [:sparse, :skip, :records],
        sparse_messages: :descriptor,
        decoder_sources: [@runtime],
        unknown_fields: :runtime_schema
      ),
      wrapped_crate("kiwi_skip", __MODULE__.SkipOnly, schema, features: [:skip]),
      wrapped_crate("kiwi_full_sparse", __MODULE__.FullSparse, schema,
        features: [:full, :sparse, :skip],
        decoder_sources: [@runtime]
      )
    ])

    :ok
  end

  defp crate(name, module, schema, opts, rust, nifs) do
    generated = RustlerGenerator.source(schema, Keyword.put(opts, :module_prefix, @prefix))

    runtime_schema =
      if opts[:unknown_fields] == :runtime_schema,
        do: "pub use KiwiRuntimeSchema as RuntimeSchema;",
        else: "pub enum RuntimeSchema {}"

    %{
      name: name,
      module: module,
      generated: generated,
      rust: runtime_schema <> "\n\n" <> rust,
      nifs: nifs
    }
  end

  # Wraps each definition's generated sparse, skip, and record functions in NIFs taking the
  # data and the binary schema it was written with, or an empty binary for none.
  defp wrapped_crate(name, module, schema, opts) do
    features = opts[:features]
    runtime_schema? = opts[:unknown_fields] == :runtime_schema

    {rust, nifs} =
      @definitions
      |> Enum.flat_map(fn definition ->
        ident = Macro.underscore(definition)

        [
          {:sparse in features, "sparse_#{ident}",
           "decode_sparse_#{ident}_from_decoder(env, &mut decoder)?"},
          {:skip in features and definition != "Kind", "skip_#{ident}",
           "{ skip_#{ident}_from_decoder(&mut decoder)?; rustler::types::atom::ok().encode(env) }"},
          {:records in features, "record_#{ident}",
           "{ let record = kiwi_decode_record(&mut decoder, kiwi_record_definitions::#{String.upcase(ident)})?; kiwi_encode_record(env, &record)? }"}
        ]
        |> Enum.filter(&elem(&1, 0))
        |> Enum.map(fn {true, nif, body} -> {nif, wrapper(nif, body, runtime_schema?)} end)
      end)
      |> Enum.map_reduce([], fn {nif, rust}, acc -> {rust, [{String.to_atom(nif), 2} | acc]} end)

    crate(name, module, schema, opts, Enum.join(rust ++ record_constants(features), "\n\n"), nifs)
  end

  # Names that are Rust keywords in snake case, such as the `Type` definition's, must still compile.
  defp record_constants(features) do
    if :records in features do
      [
        """
        const _: [u32; 4] = [
            kiwi_record_definitions::TYPE,
            kiwi_records::Type::GEN,
            kiwi_records::Type::MATCH,
            kiwi_records::Kind::TYPE,
        ];
        """
      ]
    else
      []
    end
  end

  defp wrapper(nif, body, runtime_schema?) do
    schema =
      if runtime_schema? do
        """
        let runtime_schema = if schema.is_empty() { None } else { Some(RuntimeSchema::decode(schema.as_slice())?) };
            let mut decoder = runtime::Decoder::with_schema(bytes.as_slice(), runtime_schema.as_ref());
        """
      else
        "let _ = schema;\n    let mut decoder = runtime::Decoder::new(bytes.as_slice());"
      end

    """
    #[rustler::nif]
    fn #{nif}<'a>(env: Env<'a>, bytes: Binary<'a>, schema: Binary<'a>) -> NifResult<Term<'a>> {
        #{schema}
        let term = #{body};
        decoder.finish()?;
        Ok(term)
    }
    """
  end

  # Every Node field on its own, so a failure names it, then all of them together.
  defp samples do
    [
      {"Child", %{"id" => 1, "label" => "x"}},
      {"Point", %{"x" => 0.0, "y" => 3.25}},
      {"Node", %{}}
    ] ++
      Enum.map(@node, fn {field, value} -> {"Node", %{field => value}} end) ++ [{"Node", @node}]
  end

  defp encode(definition, value, schema_source \\ @schema) do
    SchemaInterpreter.encode(KiwiCodec.parse_schema!(schema_source), definition, value)
  end

  defp elixir_module(definition), do: Module.concat(@prefix, definition)

  describe "full decoders" do
    test "return what KiwiCodec.decode/2 returns" do
      for {definition, value} <- samples() do
        binary = encode(definition, value)
        nif = :"decode_#{Macro.underscore(definition)}"

        assert {definition, value, nif(__MODULE__.Full, nif, [binary])} ==
                 {definition, value, KiwiCodec.decode(binary, elixir_module(definition))}
      end
    end

    test "reject unknown fields, truncated data, and trailing bytes" do
      binary = encode("Node", @node)
      unknown = encode("Node", Map.put(@node, "added", 1), @written_schema)
      # A uint64 whose tenth byte holds more than the one bit left.
      overflow = <<8, 255, 255, 255, 255, 255, 255, 255, 255, 255, 2, 0>>

      assert_raise KiwiCodec.DecodeError, fn ->
        KiwiCodec.decode(overflow, elixir_module("Node"))
      end

      for bad <- [
            unknown,
            overflow,
            binary_part(binary, 0, byte_size(binary) - 1),
            binary <> <<0>>
          ] do
        assert_raise ArgumentError, fn -> nif(__MODULE__.Full, :decode_node, [bad]) end
      end
    end
  end

  describe "sparse decoders" do
    test "return the fields present, as the schema interpreter reads them" do
      for module <- [__MODULE__.SparseSkip, __MODULE__.Descriptor, __MODULE__.FullSparse],
          {definition, value} <- samples() do
        binary = encode(definition, value)
        nif = :"sparse_#{Macro.underscore(definition)}"

        assert {module, definition, value, nif(module, nif, [binary, ""])} ==
                 {module, definition, value, sparse(definition, decode(definition, binary))}
      end
    end
  end

  describe "skip decoders" do
    test "consume exactly one value" do
      for module <- [
            __MODULE__.SkipOnly,
            __MODULE__.SparseSkip,
            __MODULE__.Descriptor,
            __MODULE__.FullSparse
          ],
          {definition, value} <- samples() do
        nif = :"skip_#{Macro.underscore(definition)}"
        assert nif(module, nif, [encode(definition, value), ""]) == :ok
      end
    end
  end

  describe "records" do
    test "encode as the sparse maps the sparse decoders return" do
      for {definition, value} <- samples() do
        binary = encode(definition, value)
        ident = Macro.underscore(definition)

        assert nif(__MODULE__.Descriptor, :"record_#{ident}", [binary, ""]) ==
                 nif(__MODULE__.Descriptor, :"sparse_#{ident}", [binary, ""])
      end
    end
  end

  describe "runtime schema unknown fields" do
    setup do
      written = KiwiCodec.parse_schema!(@written_schema)

      value =
        Map.merge(@node, %{
          "added" => 3,
          "extras" => [%{"note" => "new", "at" => %{"x" => 1.0, "y" => 2.0}}]
        })

      %{
        binary: SchemaInterpreter.encode(written, "Node", value),
        schema: Binary.encode(written)
      }
    end

    test "skip fields the compiled schema lacks", %{binary: binary, schema: schema} do
      expected = sparse("Node", decode("Node", encode("Node", @node)))

      assert nif(__MODULE__.Descriptor, :sparse_node, [binary, schema]) == expected
      assert nif(__MODULE__.Descriptor, :record_node, [binary, schema]) == expected
      assert nif(__MODULE__.Descriptor, :skip_node, [binary, schema]) == :ok
    end

    test "reject them without the schema", %{binary: binary} do
      for call <- [
            fn -> nif(__MODULE__.Descriptor, :sparse_node, [binary, ""]) end,
            fn -> nif(__MODULE__.SparseSkip, :sparse_node, [binary, ""]) end
          ] do
        assert_raise ArgumentError, call
      end
    end
  end

  # The NIF modules are created when the crates load, after this module compiles.
  defp nif(module, function, args), do: apply(module, function, args)

  defp decode(definition, binary) do
    SchemaInterpreter.decode(KiwiCodec.parse_schema!(@schema), definition, binary)
  end

  # The interpreter's string-keyed maps as the sparse decoders build them: underscored atom
  # keys, the generated module under `__kiwi_module__`, and enum values as underscored atoms.
  defp sparse(type, value) do
    case Enum.find(KiwiCodec.parse_schema!(@schema).definitions, &(&1.name == type)) do
      nil ->
        value

      %KiwiCodec.Schema.Enum{} ->
        value |> Macro.underscore() |> String.to_atom()

      definition ->
        Map.new(value, fn {name, field_value} ->
          field = Enum.find(definition.fields, &(&1.name == name))
          {String.to_atom(Macro.underscore(name)), sparse_field(field, field_value)}
        end)
        |> Map.put(:__kiwi_module__, elixir_module(type))
    end
  end

  defp sparse_field(%{array?: true, type: type}, values) when is_list(values),
    do: Enum.map(values, &sparse(type, &1))

  defp sparse_field(%{type: type}, value), do: sparse(type, value)
end
