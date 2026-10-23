use RustQ.Config

schema = KiwiCodec.parse_schema!("message Node { uint id = 1; string name = 2; }")

generate :decoders, "native/src/generated.rs" do
  content KiwiCodec.RustlerGenerator.source(schema,
    entrypoints: ["Node"],
    features: [:full, :sparse, :skip],
    module_prefix: "KiwiCodecGeneratorConsumer.Schema"
  )
end
