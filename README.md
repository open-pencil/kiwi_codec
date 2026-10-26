# KiwiCodec

[![Hex.pm](https://img.shields.io/hexpm/v/kiwi_codec.svg)](https://hex.pm/packages/kiwi_codec) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://kiwi-codec.hexdocs.pm)

[Kiwi](https://github.com/evanw/kiwi) schemas and messages in Elixir. Parse `.kiwi`
schemas, encode and decode messages as Elixir structs, and generate Rustler
decoders for the same schemas when decoding has to be native.

```elixir
defmodule MyApp.Node do
  use KiwiCodec, kind: :message

  field :id, 1, type: :uint
  field :name, 2, type: :string
end

binary = KiwiCodec.encode(%MyApp.Node{id: 42, name: "hello"})
KiwiCodec.decode(binary, MyApp.Node)
#=> %MyApp.Node{id: 42, name: "hello"}
```

Kiwi is the compact, schema-driven format Figma's `.fig` files use. Its wire
encoding differs from Protocol Buffers: variable-length integers and floats,
null-terminated strings, messages that carry field ids, and structs that do not.
KiwiCodec encodes it byte for byte as the OpenPencil TypeScript runtime does, and
stays generic: product schemas, such as Figma's in
[Figler](https://github.com/open-pencil/figler), live in their own packages.

## Installation

```elixir
def deps do
  [
    {:kiwi_codec, "~> 0.7.0"}
  ]
end
```

The codec is pure Elixir. The Rustler generator also needs RustQ; see
[Native decoders](#native-decoders).

## Schemas as modules

Generate a module per definition from a schema, with `@type`s and the schema's
field names in each module's metadata:

```sh
mix kiwi.gen schema.kiwi --module-prefix MyApp.Schema --out lib/generated
```

Or compile them in memory, as tests and tools may:

```elixir
KiwiCodec.compile_schema!(schema_text, module_prefix: MyApp.Schema)
```

Enums decode to atoms, and modules can be written by hand with the same DSL:

```elixir
defmodule MyApp.Kind do
  use KiwiCodec, kind: :enum

  enum_value :none, 0
  enum_value :frame, 4
end
```

A module may name a `KiwiCodec.TransformModule` in `transform_module/0` to
normalize its structs after decoding and before encoding.

## Schemas at runtime

When the schema arrives with the data, `KiwiCodec.SchemaInterpreter` encodes and
decodes string-keyed maps without generating modules:

```elixir
schema = KiwiCodec.parse_schema!(schema_text)
binary = KiwiCodec.SchemaInterpreter.encode(schema, "Thing", %{"id" => 1, "name" => "demo"})
KiwiCodec.SchemaInterpreter.decode(schema, "Thing", binary)
#=> %{"id" => 1, "name" => "demo"}
```

`SchemaInterpreter.prepare/1` indexes a schema once for repeated use.
`KiwiCodec.Schema.Binary` reads and writes schemas in Kiwi's binary form, which
is how they travel alongside data.

Data written with a newer schema can still decode into modules generated from an
older one. Pass the schema it was written with, and fields the modules do not
define are skipped:

```elixir
KiwiCodec.decode(binary, MyApp.Schema.Node, schema: written_schema)
```

## Containers

`KiwiCodec.Container` reads and builds the chunked container `.fig` files use: a
magic string, a version, and length-prefixed chunks.

```elixir
binary = KiwiCodec.Container.build([KiwiCodec.Container.deflate(schema), KiwiCodec.Container.deflate(data)])
%{version: 101, chunks: [schema_chunk, data_chunk]} = KiwiCodec.Container.parse(binary)
```

## Native decoders

`KiwiCodec.RustlerGenerator` generates Rustler decoders for a schema, to decode
in Rust what is too large or too hot for Elixir. It needs
[RustQ](https://hex.pm/packages/rustq), an optional dependency of KiwiCodec, so
add it where you generate:

```elixir
{:rustq, "~> 1.0.0-rc.21", only: [:dev, :test], runtime: false}
```

Then generate from `rustq.exs`, and let `mix rustq.gen` write the file and
`mix rustq.gen --check` keep it fresh:

```elixir
use RustQ.Config

schema = KiwiCodec.parse_schema!(File.read!("priv/schema.kiwi"))

generate :decoders, "native/my_nif/src/generated.rs" do
  content KiwiCodec.RustlerGenerator.source(schema,
    entrypoints: ["Node"],
    module_prefix: "MyApp.Schema"
  )
end
```

`entrypoints: ["Node"]` generates a `decode_node` NIF that returns the same
structs `KiwiCodec.decode/2` does. Other features generate sparse maps of the
fields present, skip functions, native records Rust code can work with, and
decoders that skip fields the compiled schema lacks. The crate provides the
`Decoder` the generated code reads with; KiwiCodec ships a complete one to copy.
[Native decoders](https://kiwi-codec.hexdocs.pm/native-decoders.html) covers
each feature, entrypoints, and the `Decoder`.

## Development

See [Internals](guides/internals.md) for how the codec and the generator are put
together, and the checks to run when changing the generator.

```sh
mix deps.get
mix ci
```

`mix ci` builds the generated Rust, so it needs Rust and Cargo.
`elixir bench/codec_bench.exs` compares generated modules with the schema
interpreter on small and 256-field messages.

## License

MIT
