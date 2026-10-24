# Internals

How KiwiCodec is put together, for people changing it. Using the Rustler
generator is covered in [Native decoders](native-decoders.md).

## Layout

- `lib/` is the codec: the schema parser and binary schema format
  (`KiwiCodec.Schema.*`), wire primitives (`KiwiCodec.Wire.*`), the DSL and the
  modules it generates (`KiwiCodec.DSL`, `KiwiCodec.GeneratedModule.*`), encoding
  and decoding of generated structs (`KiwiCodec.Encoder`, `KiwiCodec.Decoder`),
  and the schema interpreter. It has no dependency beyond `varint`.
- `codegen/` is the Rustler generator. Every module there is wrapped in
  `if Code.ensure_loaded?(RustQ)`, because RustQ is optional: projects that
  depend on KiwiCodec get the generator only where they also depend on RustQ.
- Tests mirror the source tree. `test/package/` builds the package and compiles
  it in two consumer projects, one without RustQ and one generating Rust.

## Rustler generator

The generator serves two goals at once:

1. Keep generator code semantic and maintainable in Elixir.
2. Keep generated Rust compact enough for large schemas, such as Figma's.

For repetitive schema decoders, those goals are served by a compact macro
boundary rather than by fully expanding every decoder body.

### Layers

The generator is organized as a small pipeline:

1. Schema definitions are parsed and selected by `KiwiCodec.RustlerGenerator`.
2. Definition-specific modules (`Definition`, `Sparse`, and `Skip`) derive
   semantic field metadata and field expressions from the schema.
3. `KiwiCodec.RustlerGenerator.DecoderMacro`, for full decoders, and the
   `Sparse` and `Skip` modules lower that metadata to compact Rust macro
   invocations such as `kiwi_message_decoder!`, `kiwi_sparse_struct_decoder!`,
   and `kiwi_skip_message_decoder!`.
4. `KiwiCodec.RustlerGenerator.Splice` selects the shared Rust macro definitions
   and helper functions consumed by those invocations. The full, sparse, and
   skip helper modules author those macros with RustQ `defrustmacro`, `defrust`,
   type metadata, and method metadata read from the `Decoder` source: the
   reference `decoder.rs` beside `KiwiCodec.RustlerGenerator.Decoder`, or the
   caller's `decoder_sources:`.
5. `KiwiCodec.RustlerGenerator.Entrypoint` emits Rustler NIF entrypoints with
   RustQ `defnif`, where the wrapper control flow is small and readable.

This split keeps schema logic in Elixir while avoiding thousands of repeated
expanded Rust function bodies.

Three pieces are shared by every schema and written as Rust under `templates/`:
the record runtime, the runtime schema that skips unknown fields, and the atom
cache. They are ordinary Rust APIs, documented for the Rust code that uses
them, rather than repetitive decoder shapes.

### Compact RustQ macro boundary

The macros selected by `Splice` are a compact RustQ-authored boundary. They are
shared implementations for highly repetitive decoder shapes, but they should be
authored through `defrustmacro`, `defrust`, type metadata, and RustQ AST helpers
rather than through raw Rust heredocs or ad hoc token strings.

When changing full, sparse, or skip decoder generation:

- Prefer semantic Elixir metadata and helpers first.
- Keep compact schema-specific output as macro invocations when the expanded
  body would be repetitive.
- Use RustQ AST or Rusty-Elixir helpers for local expression/arm/function
  generation where it remains compact, such as skip field arms used by
  downstream custom templates.
- Declare a `Decoder` method in the reference `decoder.rs` before adding
  `unwrap!`, verbose propagation `case` expressions, or duplicate method
  metadata to a helper.
- Do not replace compact decoder macro invocations with fully expanded Rust just
  to say the generator is "AST-backed" or "defrust-backed".

A good change should make the Elixir generator clearer without increasing large
schema output size.

### Tests

`KiwiCodec.RustlerGenerator.NativeTest` builds the generated decoders for every
feature with the reference `Decoder`, loads them as NIFs, and checks what they
return against `KiwiCodec.decode/2` and `KiwiCodec.SchemaInterpreter`. A
generator change that produces Rust that does not compile, or decodes
differently, fails there; tests of the generated text are not needed for it.

### Checklist

Before committing generator changes:

1. Generate Rust for a schema that exercises full, sparse, and skip decoders,
   before and after the change, and compare the size.
2. Run `mix ci`, which builds and runs the generated Rust.
3. Generate Figler's decoders with this checkout, as Figler's schema is the
   largest consumer: set `KIWI_CODEC_PATH` in Figler, run `mix rustq.gen`, and
   check that its crate compiles. Restore Figler's generated files afterwards.
