# Changelog

## v0.5.1 - 2026-10-25

### Changed

- `KiwiCodec.RustlerGenerator.Records` provides the record runtime to RustQ.
  RustQ code that works with records names the module through `alias` and
  writes `Records.kiwi_record()` in its specs, instead of reading the runtime's
  Rust file from the dependency's directory. The runtime is `templates/records.rs`. This needs RustQ 1.0.0-rc.16.

## v0.5.0 - 2026-10-24

### Added

- `KiwiCodec.RustlerGenerator.Decoder` documents the `Decoder` generated
  decoders read with, and ships `decoder.rs`, a complete one. The generator
  reads its method signatures unless `:decoder_sources` names another
  `Decoder`, so every feature knows which reads return a `NifResult`.
- Projects that depend on KiwiCodec can use `KiwiCodec.RustlerGenerator`.
  RustQ is an optional dependency, and the generator compiles wherever it is
  available, such as a project's development and test builds; it used to
  compile only in KiwiCodec's own, so projects loaded its sources themselves.
- `KiwiCodec.Schema.Token` has a `kind`: `:identifier`, `:integer`,
  `:symbol`, or `:eof`.

### Changed

- The docs have a Native decoders guide covering each generator feature,
  entrypoints, and the `Decoder`. The generator architecture guide is now
  Internals, for people changing KiwiCodec, and the module groups separate the
  public API from internals.
- The schema tokenizer reads with binary patterns rather than a regular
  expression, and is about 14 times faster on Figma's schema. Tokens,
  positions, and errors are unchanged.
- Skip and sparse helpers are always built from `Decoder` metadata. Without
  `:decoder_sources`, they used to come from a separate set of helpers that
  did not know which reads could fail.
- Item macro rows in generated Rust separate their values with commas, as
  RustQ 1.0.0-rc.14 writes them.
- Records name a definition whose name is a Rust keyword with a raw
  identifier, such as `kiwi_records::r#type`, rather than appending `_` from a
  list of keywords that missed `gen`, `try`, and others.
- Generated Rust builds on rustler 0.37 to 0.39. It used to call
  `rustler::wrapper`, which rustler 0.39 removed.
- Require RustQ 1.0.0-rc.14 for code generation.

### Removed

- `RustlerGenerator.RustExpr.ident/1` and `indent/2`, and
  `RustlerGenerator.Skip.field_expr/2`. `RustExpr.primitive/1` returns RustQ
  AST rather than Rust source.

### Fixed

- The `:full` feature, the default, generates Rust that compiles and decodes
  as `KiwiCodec.decode/2` does. Its entrypoints moved the decoder they then
  finished, its message macro called an undefined function, its reads were
  not propagated with `?`, its strings were read without `env`, and a float
  that is infinite or NaN raised instead of decoding to an atom.
- Generating both sparse and skip decoders without `:decoder_sources` defined
  `kiwi_skip_descriptor_kind` twice, and skip decoders alone with
  `:decoder_sources` called it without defining it.
- A schema name that is not a Rust identifier fails where it is rendered,
  rather than having its other characters replaced with `_`, which could give
  two names the same Rust name.

## v0.4.0 - 2026-10-23

- Add the `:unknown_fields` Rustler generator option. `:runtime_schema` makes
  generated message decoders skip fields the compiled schema does not define,
  using a `KiwiRuntimeSchema` read from the schema that accompanies the data, so
  data written with a newer, compatible schema decodes instead of failing with
  `BadArg`. The default, `:error`, keeps rejecting such fields.
- Route every generated message decoder's unknown fields through one
  `kiwi_unknown_field` helper, and pass full message decoders their definition
  name.
- Accept a `:schema` option in `KiwiCodec.decode/3` to skip message fields the
  generated modules do not define, using the schema the data was written with.
- Add `KiwiCodec.SchemaInterpreter.skip_message_field/4`.
- Add the `:records` Rustler generator feature. It decodes Kiwi data into
  native records Rust code can read, change, and share without building Elixir
  terms, then encodes them as the sparse maps generated decoders return,
  optionally only some fields. Generated constants name each definition, field,
  and enum value; records have typed getters and helpers that update nested
  records and scalar, string, enum, and float-array fields. See
  `KiwiCodec.RustlerGenerator.Records`.
- Sparse decoders intern their module and field-name atoms once instead of for
  every map they build, which took two thirds of the time decoding large files.
- Require RustQ 1.0.0-rc.13 for code generation.
- Rename the Rustler generator's skip, sparse, and full decoder helpers by
  family: `RustlerGenerator.SkipHelpers`, `SkipValueHelpers`, and
  `SkipDescriptor` are `RustlerGenerator.Skip.Helpers`, `Skip.ValueHelpers`,
  and `Skip.Descriptor`; `SparseHelpers` is `Sparse.Helpers`; and
  `FullDecoderHelpers` is `Full.Helpers`.

## v0.3.1 - 2026-07-18

- Compile the RustQ-backed Rustler generator only in development and test
  environments, keeping production codec consumers free of RustQ and its
  development-tool dependency graph.
- Continue shipping the Rustler generator source for development-time native
  generation while keeping the production runtime package limited to the Kiwi
  codec and schema APIs.
- Remove the unused Jason dependency from the production package.

## v0.3.0 - 2026-07-17

- Restore the required slice borrow for match-backed sparse field tables when
  decoder source metadata is enabled.
- Hide internal Rust-only helper types from ExDoc type-reference rendering.
- Add reusable prepared runtime schemas with indexed definition, message-field,
  and enum lookup for repeated `SchemaInterpreter` calls.
- Replace the timer-loop codec benchmark with Benchee coverage for small and
  256-field sparse/dense static and interpreted codecs, including allocation
  measurements.
- Clarify Rustler generator architecture docs now that compact decoder macros
  are RustQ-authored rather than raw Rust heredoc escape boundaries.
- Deduplicate Rustler generator skip descriptor selection and remove exact clone
  findings from the generator helper modules.
- Add optional `decoder_sources` metadata for RustQ-authored skip helpers.
- Emit Rustler macro prelude helpers only for requested generator features.
- Add opt-in descriptor-backed sparse message generation with
  `sparse_messages: :descriptor`.
- Move sparse primitive value helpers, descriptor scanning, descriptor dispatch,
  and sparse descriptor declarations into RustQ-authored `defrust` / `@type`
  support.
- Author the sparse message descriptor macro with item-generating
  `defrustmacro` and compact `repeat` macro-template support.
- Share descriptor field inventories between sparse and skip message decoders
  when both descriptor sparse and skip features are generated.
- Author sparse enum and sparse struct descriptor decoding with RustQ-authored
  `defrust` helpers and item-generating `defrustmacro`.
- Avoid emitting raw match-backed sparse/skip message macros when decoder-source
  descriptor sparse generation does not use them.
- Author decoder-source skip struct decoders with RustQ-authored `defrust`
  helpers and item-generating `defrustmacro`.
- Replace active shared sparse/skip descriptor `kiwi_skip_kind!` token macro use
  with explicit descriptor metadata and RustQ-authored enum construction.
- Move descriptor-backed skip message scanning into RustQ-authored `defrust`
  helpers with sorted field lookup.
- Generate skip descriptor function, enum, and field declarations from RustQ
  type metadata when decoder sources are available.
- Collapse the separate sparse bytes descriptor mode into ordinary `one`
  descriptor mode.

## v0.2.2 - 2026-06-28

- Centralize primitive Rustler decoder metadata.
- Compact generated skip decoders.
- Deduplicate sparse enum decoders when full enum decoders are generated.
- Compact generated enum decoders.
- Remove the unused Rustler decoder macro path.
- Update RustQ dependency to `~> 0.8.2`.

## v0.2.1 - 2026-06-26

- Generate Rustler decoders through shared Rust macros to reduce repeated generated source.
- Add generic Rustler sparse and skip decoder families for projection-oriented native backends.

## v0.2.0 - 2026-06-26

- Delegate LEB128/ZigZag integer encoding to the `varint` package while keeping Kiwi-specific range and error handling.
- Replace vague `FieldProps`/`MessageProps` modules with `KiwiCodec.Metadata` and `KiwiCodec.Metadata.Field`.
- Rename the Kiwi variable-length float wire module to `KiwiCodec.Wire.VarFloat`.
- Rename generated module metadata API from `__kiwi_props__/0` to `__kiwi_metadata__/0`.
- Split Rustler generator naming, selection, helper splice, and decoder macro concerns into dedicated modules.
- Rename generated Elixir source rendering from `KiwiCodec.Generator` to `KiwiCodec.ModuleGenerator`.
- Clarify generated-codec and runtime helper names around definitions, wire fields, and wire types.
- Replace caller-owned Rustler templates with `KiwiCodec.RustlerGenerator.source/2` for complete generated Rust source.
- Centralize Kiwi primitive type metadata in `KiwiCodec.PrimitiveType`.
- Rename schema runtime interpretation to `KiwiCodec.SchemaInterpreter`.
- Split vague `KiwiCodec.Compiler` responsibilities into `KiwiCodec.ModuleCompiler` and `KiwiCodec.FileGenerator`.
- Split parsed schema members into `KiwiCodec.Schema.Field` with `id` and `KiwiCodec.Schema.EnumVariant` with `value`.
- Replace overloaded parsed schema definitions with `KiwiCodec.Schema.Enum`, `KiwiCodec.Schema.Struct`, and `KiwiCodec.Schema.Message`.
- Extract compact binary schema type-reference encoding into `KiwiCodec.Schema.Binary.TypeIndex`.
- Split Rustler generator definition emission, field expressions, and entrypoints into dedicated modules.
- Split generated-module metadata, shape, and typespec emission out of `KiwiCodec.DSL`.
- Split schema tokenization and validation out of `KiwiCodec.Schema.Parser`.
- Group published HexDocs modules without hiding source documentation.
- Refresh README installation instructions for the latest released version.
- Infer Rustler generator entrypoint names and selected definitions from requested schema definitions.
- Render Rustler generator source prelude with RustQ AST imports instead of raw Rust strings.
- Infer Rustler generator entrypoints from matching exported NIF stub modules.
- Infer Rustler generator entrypoints from explicit NIF stub metadata modules without loading Rustler modules.
- Document inferred Rustler entrypoints and NIF stub metadata usage.

## v0.1.1 - 2026-06-25

- Reject unexpected characters while parsing `.kiwi` schema text.
- Normalize malformed binary schema failures to `KiwiCodec.DecodeError`.
- Document internal modules and Rustler generator template requirements.
- Reuse RustQ Rustler helper splices for generated native struct term construction.

## v0.1.0 - 2026-06-25

- Initial Kiwi wire codec, schema parser, runtime interpreter, DSL, and code generator.
