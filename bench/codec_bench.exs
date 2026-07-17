Mix.install(
  [
    {:benchee, "~> 1.4"},
    {:kiwi_codec, path: Path.expand("..", __DIR__)}
  ],
  consolidate_protocols: false
)

defmodule BenchSchema.Kind do
  use KiwiCodec, kind: :enum

  enum_value(:node, 1)
end

defmodule BenchSchema.Point do
  use KiwiCodec, kind: :struct

  field(:x, 1, type: :float)
  field(:y, 2, type: :float)
end

defmodule BenchSchema.Node do
  use KiwiCodec, kind: :message

  field(:id, 1, type: :uint)
  field(:kind, 2, type: {:enum, BenchSchema.Kind})
  field(:name, 3, type: :string)
  field(:position, 4, type: BenchSchema.Point)
end

schema_text = """
enum Kind { NODE = 1; }
struct Point { float x; float y; }
message Node { uint id = 1; Kind kind = 2; string name = 3; Point position = 4; }
"""

schema = KiwiCodec.parse_schema!(schema_text)
prepared_schema = KiwiCodec.SchemaInterpreter.prepare(schema)

static_value =
  struct(BenchSchema.Node,
    id: 1,
    kind: :node,
    name: "demo",
    position: struct(BenchSchema.Point, x: 1.0, y: 2.0)
  )

runtime_value = %{
  "id" => 1,
  "kind" => "NODE",
  "name" => "demo",
  "position" => %{"x" => 1.0, "y" => 2.0}
}

static_binary = KiwiCodec.encode(static_value)
runtime_binary = KiwiCodec.SchemaInterpreter.encode(schema, "Node", runtime_value)

wide_schema_text =
  "message Wide {\n" <>
    Enum.map_join(1..256, "\n", &"  uint f#{&1} = #{&1};") <>
    "\n}"

wide_schema = KiwiCodec.parse_schema!(wide_schema_text)
prepared_wide_schema = KiwiCodec.SchemaInterpreter.prepare(wide_schema)
KiwiCodec.compile_schema!(wide_schema_text, module_prefix: BenchSchema)
wide_module = BenchSchema.Wide
sparse_fields = [1, 128, 255, 256]
sparse_static = struct(wide_module, Map.new(sparse_fields, &{String.to_atom("f#{&1}"), &1}))
sparse_runtime = Map.new(sparse_fields, &{"f#{&1}", &1})
dense_static = struct(wide_module, Map.new(1..256, &{String.to_atom("f#{&1}"), &1}))
dense_runtime = Map.new(1..256, &{"f#{&1}", &1})
sparse_static_binary = KiwiCodec.encode(sparse_static)
sparse_runtime_binary = KiwiCodec.SchemaInterpreter.encode(wide_schema, "Wide", sparse_runtime)
dense_static_binary = KiwiCodec.encode(dense_static)
dense_runtime_binary = KiwiCodec.SchemaInterpreter.encode(wide_schema, "Wide", dense_runtime)

Benchee.run(
  %{
    "small static encode" => fn -> KiwiCodec.encode(static_value) end,
    "small static decode" => fn -> KiwiCodec.decode(static_binary, BenchSchema.Node) end,
    "small runtime encode" => fn ->
      KiwiCodec.SchemaInterpreter.encode(schema, "Node", runtime_value)
    end,
    "small runtime decode" => fn ->
      KiwiCodec.SchemaInterpreter.decode(schema, "Node", runtime_binary)
    end,
    "small prepared runtime encode" => fn ->
      KiwiCodec.SchemaInterpreter.encode(prepared_schema, "Node", runtime_value)
    end,
    "small prepared runtime decode" => fn ->
      KiwiCodec.SchemaInterpreter.decode(prepared_schema, "Node", runtime_binary)
    end,
    "wide sparse static encode" => fn -> KiwiCodec.encode(sparse_static) end,
    "wide sparse static decode" => fn -> KiwiCodec.decode(sparse_static_binary, wide_module) end,
    "wide sparse runtime encode" => fn ->
      KiwiCodec.SchemaInterpreter.encode(wide_schema, "Wide", sparse_runtime)
    end,
    "wide sparse runtime decode" => fn ->
      KiwiCodec.SchemaInterpreter.decode(wide_schema, "Wide", sparse_runtime_binary)
    end,
    "wide sparse prepared runtime encode" => fn ->
      KiwiCodec.SchemaInterpreter.encode(prepared_wide_schema, "Wide", sparse_runtime)
    end,
    "wide sparse prepared runtime decode" => fn ->
      KiwiCodec.SchemaInterpreter.decode(prepared_wide_schema, "Wide", sparse_runtime_binary)
    end,
    "wide dense static encode" => fn -> KiwiCodec.encode(dense_static) end,
    "wide dense static decode" => fn -> KiwiCodec.decode(dense_static_binary, wide_module) end,
    "wide dense runtime encode" => fn ->
      KiwiCodec.SchemaInterpreter.encode(wide_schema, "Wide", dense_runtime)
    end,
    "wide dense runtime decode" => fn ->
      KiwiCodec.SchemaInterpreter.decode(wide_schema, "Wide", dense_runtime_binary)
    end,
    "wide dense prepared runtime encode" => fn ->
      KiwiCodec.SchemaInterpreter.encode(prepared_wide_schema, "Wide", dense_runtime)
    end,
    "wide dense prepared runtime decode" => fn ->
      KiwiCodec.SchemaInterpreter.decode(prepared_wide_schema, "Wide", dense_runtime_binary)
    end
  },
  warmup: 1,
  time: 3,
  memory_time: 1
)
