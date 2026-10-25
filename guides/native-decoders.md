# Native decoders

`KiwiCodec.RustlerGenerator.source/2` writes Rust that decodes Kiwi data for a
schema inside a Rustler NIF. It is for data too large or too hot to decode in
Elixir. What it decodes matches `KiwiCodec.decode/2` and
`KiwiCodec.SchemaInterpreter`, and KiwiCodec's tests check that for every
feature.

## Setup

The generator needs RustQ, an optional dependency of KiwiCodec. Add it where you
generate, usually only in development and test:

```elixir
{:rustq, "~> 1.0.0-rc.17", only: [:dev, :test], runtime: false}
```

Generate from `rustq.exs`. `mix rustq.gen` writes the file, and
`mix rustq.gen --check`, in CI, fails when it is stale:

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

Include the generated file in the crate beside a `Decoder`; see
[The Decoder](#the-decoder).

## Features

`:features` picks what to generate, `[:full]` by default. Each feature generates
one function per definition, taking the `Decoder` positioned at a value:

| Feature | Generates | Returns |
| --- | --- | --- |
| `:full` | `decode_<name>_from_decoder(env, &mut decoder)` | the struct `KiwiCodec.decode/2` returns |
| `:sparse` | `decode_sparse_<name>_from_decoder(env, &mut decoder)` | a map of the fields present, with `__kiwi_module__` |
| `:skip` | `skip_<name>_from_decoder(&mut decoder)` | nothing; consumes the value |
| `:records` | `kiwi_decode_record(&mut decoder, definition)` | a `KiwiRecord` Rust code can read and change |

`<name>` is the definition's name in snake case. Enums have no skip function.

Full decoders build the structs of the modules `:module_prefix` names, so those
modules should exist in Elixir, generated with `mix kiwi.gen` or
`KiwiCodec.compile_schema!/2`. Sparse maps key fields by atoms and give enum
values as atoms:

```elixir
%{__kiwi_module__: MyApp.Schema.Node, name: "frame", kind: :ellipse}
```

Sparse and skip decoders together let native code read some fields and skip the
rest without building terms for them. `sparse_messages: :descriptor` generates
smaller sparse message decoders that share their field tables with skip
decoders; measure before choosing it for hot schemas.

Records are decoded values Rust code can work with before deciding what to
return. `kiwi_encode_record(env, &record)` encodes one as the sparse map the
sparse decoder would return. The generated constants name each definition,
field, and enum value; see `KiwiCodec.RustlerGenerator.Records`.

## Entrypoints

`:entrypoints` adds NIFs that decode a whole binary with the full decoder and
fail on trailing bytes:

```rust
#[rustler::nif(schedule = "DirtyCpu")]
fn decode_node<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>>
```

It takes definition names, which infer `decode_<name>` NIFs, `{nif_name,
definition_name}` pairs, `:all`, a NIF stub module whose one-argument `decode_*`
functions name definitions, or `{:nif_stubs, module}` for a module whose
`stubs/0` lists them. Only the definitions entrypoints need, and their
dependencies, are generated unless `:definitions` names others.

For the other features, write the NIF yourself. With `features: [:sparse]`, this
one returns the sparse map of a `Node`:

```rust
#[rustler::nif]
fn decode_sparse_node<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
    let mut decoder = Decoder::new(bytes.as_slice());
    let term = decode_sparse_node_from_decoder(env, &mut decoder)?;
    decoder.finish()?;
    Ok(term)
}
```

## Unknown fields

Message decoders reject a field the compiled schema does not define, as
`KiwiCodec.decode/2` does without a schema. Data written with a newer schema
needs that schema to be skipped. With `unknown_fields: :runtime_schema`, the
generated code includes a `KiwiRuntimeSchema` read from a schema in Kiwi's
binary form, and the `Decoder` hands it to the generated decoders:

```rust
let schema = KiwiRuntimeSchema::decode(schema_bytes.as_slice())?;
let mut decoder = Decoder::with_schema(bytes.as_slice(), Some(&schema));
```

See `KiwiCodec.RustlerGenerator.UnknownFields`.

## The Decoder

The generated code reads with a `Decoder<'a>` the crate provides, imported from
`crate::runtime::Decoder` unless `:decoder` names another path.
`KiwiCodec.RustlerGenerator.Decoder` lists the methods each feature uses and
ships `decoder.rs`, a complete one to copy into the crate.

RustQ reads the `Decoder`'s method signatures to know which reads return a
`NifResult` and need `?`. A `Decoder` whose signatures differ from the reference
one is passed with `:decoder_sources`:

```elixir
KiwiCodec.RustlerGenerator.source(schema,
  entrypoints: ["Node"],
  module_prefix: "MyApp.Schema",
  decoder_sources: ["native/my_nif/src/runtime.rs"]
)
```

## Rustler versions

The generated code builds with rustler 0.37 to 0.39.
