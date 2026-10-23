# Rustler generator architecture

KiwiCodec's Rustler generator is optimized for two goals at the same time:

1. Keep generator code semantic and maintainable in Elixir.
2. Keep generated Rust source compact enough for large downstream schemas.

For repetitive schema decoders, those goals are served by a compact macro
boundary rather than by fully expanding every decoder body.

## Layers

The generator is organized as a small pipeline:

1. Schema definitions are parsed and selected by `KiwiCodec.RustlerGenerator`.
2. Definition-specific modules (`Definition`, `Sparse`, and `Skip`) derive
   semantic field metadata and field expressions from the schema.
3. `KiwiCodec.RustlerGenerator.DecoderMacro` lowers that metadata to compact
   Rust macro invocations such as `kiwi_message_decoder!`,
   `kiwi_sparse_message_decoder!`, and `kiwi_skip_message_decoder!`.
4. `KiwiCodec.RustlerGenerator.Splice` selects the shared Rust macro definitions
   and helper functions consumed by those invocations. The full, sparse, and
   skip helper modules author those macros with RustQ `defrustmacro`, `defrust`,
   type metadata, and method metadata read from the `Decoder` source: the
   reference `decoder.rs` beside `KiwiCodec.RustlerGenerator.Decoder`, or the
   caller's `decoder_sources:`.
5. `KiwiCodec.RustlerGenerator.Entrypoint` emits Rustler NIF entrypoints through
   RustQ `defrust`, where the wrapper control flow is small and readable.

This split keeps schema logic in Elixir while avoiding thousands of repeated
expanded Rust function bodies.

Three pieces are shared by every schema and written as Rust under `templates/`:
the record runtime, the runtime schema that skips unknown fields, and the atom
cache. They are ordinary Rust APIs, documented for the Rust code that uses
them, rather than repetitive decoder shapes.

## Compact RustQ macro boundary

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

## Dogfooding size guardrail

Figler is the main downstream stress test for generated Rust size. It should be
used as a private dogfood check, not updated or published automatically.

As of the current generator polish, Figler with local KiwiCodec and
`decoder_sources: ["native/src/runtime.rs"]` should generate approximately:

- about `13,600` lines
- about `585,000` bytes

Small formatting or schema changes can move this slightly, but a large jump
usually means a compact macro boundary was accidentally expanded.

## Tests

`KiwiCodec.RustlerGenerator.NativeTest` builds the generated decoders for every
feature with the reference `Decoder`, loads them as NIFs, and checks what they
return against `KiwiCodec.decode/2` and `KiwiCodec.SchemaInterpreter`. A
generator change that produces Rust that does not compile, or decodes
differently, fails there; tests of the generated text are not needed for it.

## Practical checklist

Before committing Rustler generator changes:

1. Capture a generated Rust baseline for a schema that exercises full, sparse,
   and skip decoders.
2. Make the smallest semantic change.
3. Confirm generated output is unchanged or intentionally smaller.
4. Run KiwiCodec `mix ci` and warning-free docs.
5. Dogfood Figler with a temporary local KiwiCodec dependency.
6. Restore Figler before committing KiwiCodec changes unless a Figler update was
   explicitly requested.
