/// A binary Kiwi schema read at runtime.
///
/// Encoded Kiwi data is not self-describing, so a decoder compiled from one schema
/// cannot step over a message field added by a newer one. Files usually carry the
/// schema they were written with; this keeps the types it declares so compiled
/// decoders can skip fields they do not know instead of rejecting the data.
pub struct KiwiRuntimeSchema {
    definitions: Vec<KiwiRuntimeDefinition>,
    by_name: std::collections::HashMap<String, usize>,
}

struct KiwiRuntimeDefinition {
    kind: u8,
    /// Struct fields in wire order; message fields sorted by id.
    fields: Vec<KiwiRuntimeField>,
}

#[derive(Clone, Copy)]
struct KiwiRuntimeField {
    id: u32,
    /// Bitwise-negated primitive index when negative, otherwise a definition index.
    type_index: i32,
    array: bool,
}

const KIWI_RUNTIME_ENUM: u8 = 0;
const KIWI_RUNTIME_STRUCT: u8 = 1;
const KIWI_RUNTIME_MESSAGE: u8 = 2;
const KIWI_RUNTIME_PRIMITIVES: i32 = 8;
const KIWI_RUNTIME_BYTE: i32 = !1;
const KIWI_RUNTIME_MAX_DEPTH: usize = 512;

impl KiwiRuntimeSchema {
    /// Reads a schema in Kiwi's compact binary format.
    pub fn decode(bytes: &[u8]) -> NifResult<Self> {
        let mut decoder = Decoder::new(bytes);
        let count = decoder.read_var_uint()? as usize;
        let mut definitions = Vec::with_capacity(count.min(bytes.len()));
        let mut by_name = std::collections::HashMap::with_capacity(count.min(bytes.len()));

        for index in 0..count {
            let name = decoder.read_string_value()?;
            let kind = decoder.read_byte()?;
            if kind > KIWI_RUNTIME_MESSAGE {
                return Err(Error::BadArg);
            }

            let field_count = decoder.read_var_uint()? as usize;
            let mut fields = Vec::with_capacity(field_count.min(bytes.len()));
            for _ in 0..field_count {
                decoder.skip_string()?;
                let type_index = decoder.read_var_int()?;
                let array = decoder.read_byte()? != 0;
                let id = decoder.read_var_uint()?;
                fields.push(KiwiRuntimeField { id, type_index, array });
            }

            if kind == KIWI_RUNTIME_MESSAGE {
                fields.sort_by_key(|field| field.id);
            }

            definitions.push(KiwiRuntimeDefinition { kind, fields });
            by_name.insert(name, index);
        }

        decoder.finish()?;

        let valid_type = |type_index: i32| {
            (type_index < 0 && !type_index < KIWI_RUNTIME_PRIMITIVES)
                || (type_index >= 0 && (type_index as usize) < definitions.len())
        };

        let valid = definitions
            .iter()
            .filter(|definition| definition.kind != KIWI_RUNTIME_ENUM)
            .flat_map(|definition| definition.fields.iter())
            .all(|field| valid_type(field.type_index));

        if valid {
            Ok(Self { definitions, by_name })
        } else {
            Err(Error::BadArg)
        }
    }

    /// Skips the value of `field` in the message named `definition`.
    pub fn skip_field(&self, decoder: &mut Decoder<'_>, definition: &str, field: u32) -> NifResult<()> {
        let index = *self.by_name.get(definition).ok_or(Error::BadArg)?;
        let field = self.message_field(index, field)?;
        self.skip_value(decoder, field, 0)
    }

    fn message_field(&self, definition: usize, id: u32) -> NifResult<KiwiRuntimeField> {
        let fields = &self.definitions[definition].fields;
        fields
            .binary_search_by_key(&id, |field| field.id)
            .map(|index| fields[index])
            .map_err(|_| Error::BadArg)
    }

    fn skip_value(&self, decoder: &mut Decoder<'_>, field: KiwiRuntimeField, depth: usize) -> NifResult<()> {
        if !field.array {
            return self.skip_one(decoder, field.type_index, depth);
        }

        if field.type_index == KIWI_RUNTIME_BYTE {
            return decoder.skip_byte_array();
        }

        let count = decoder.read_var_uint()?;
        for _ in 0..count {
            self.skip_one(decoder, field.type_index, depth)?;
        }
        Ok(())
    }

    fn skip_one(&self, decoder: &mut Decoder<'_>, type_index: i32, depth: usize) -> NifResult<()> {
        if depth > KIWI_RUNTIME_MAX_DEPTH {
            return Err(Error::BadArg);
        }

        if type_index < 0 {
            return match !type_index {
                0 => decoder.read_bool().map(|_| ()),
                1 => decoder.read_byte().map(|_| ()),
                2 => decoder.read_var_int().map(|_| ()),
                3 => decoder.read_var_uint().map(|_| ()),
                4 => decoder.read_var_float_value().map(|_| ()),
                5 => decoder.skip_string(),
                6 => decoder.read_var_int64().map(|_| ()),
                _ => decoder.read_var_uint64().map(|_| ()),
            };
        }

        let index = type_index as usize;
        match self.definitions[index].kind {
            KIWI_RUNTIME_ENUM => decoder.read_var_uint().map(|_| ()),
            KIWI_RUNTIME_STRUCT => {
                for field in &self.definitions[index].fields {
                    self.skip_value(decoder, *field, depth + 1)?;
                }
                Ok(())
            }
            _ => loop {
                match decoder.read_var_uint()? {
                    0 => return Ok(()),
                    id => {
                        let field = self.message_field(index, id)?;
                        self.skip_value(decoder, field, depth + 1)?;
                    }
                }
            },
        }
    }
}

/// Skips a message field the compiled schema does not define, using the schema the
/// decoder was given for the data. Without one, the field is rejected.
fn kiwi_unknown_field(decoder: &mut Decoder<'_>, definition: &str, field: u32) -> NifResult<()> {
    match decoder.runtime_schema() {
        Some(schema) => schema.skip_field(decoder, definition, field),
        None => Err(Error::BadArg),
    }
}
