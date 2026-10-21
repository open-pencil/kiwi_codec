/// A decoded Kiwi value. Strings, byte arrays, records, and arrays are shared, so cloning a
/// value never copies its contents.
#[derive(Clone, Debug, PartialEq)]
pub enum KiwiValue {
    Bool(bool),
    Byte(u8),
    Int(i32),
    Uint(u32),
    Float(f32),
    String(std::sync::Arc<str>),
    Int64(i64),
    Uint64(u64),
    /// An enum value and the index of the enum's definition.
    Enum(u32, u32),
    Bytes(std::sync::Arc<[u8]>),
    Record(KiwiRecord),
    Array(std::sync::Arc<[KiwiValue]>),
}

/// A decoded Kiwi message or struct: its definition and the fields it sets, sorted by field
/// id. Records are immutable; changing one returns a new record sharing the unchanged values,
/// as an Elixir map does.
#[derive(Clone, Debug, PartialEq)]
pub struct KiwiRecord {
    definition: u32,
    fields: std::sync::Arc<[(u32, KiwiValue)]>,
}

/// A schema definition as generated record code describes it.
pub struct KiwiRecordDefinition {
    pub kind: u8,
    /// The definition's name in the schema.
    pub name: &'static str,
    /// The Elixir module named in a decoded map's `__kiwi_module__`.
    pub module: &'static str,
    /// Fields sorted by id; a struct's ids follow its wire order.
    pub fields: &'static [KiwiRecordField],
    /// Enum variants sorted by value.
    pub variants: &'static [KiwiRecordVariant],
}

pub struct KiwiRecordField {
    pub id: u32,
    /// The field's key in a decoded map.
    pub name: &'static str,
    /// A bitwise-negated primitive index when negative, otherwise a definition index.
    pub type_index: i32,
    pub array: bool,
}

pub struct KiwiRecordVariant {
    pub value: u32,
    /// The variant's atom in a decoded map.
    pub name: &'static str,
}

const KIWI_RECORD_ENUM: u8 = 0;
const KIWI_RECORD_STRUCT: u8 = 1;
const KIWI_RECORD_BYTE: i32 = !1;
const KIWI_RECORD_MAX_DEPTH: usize = 512;

impl KiwiRecord {
    /// A record of `definition` that sets no fields.
    pub fn new(definition: u32) -> Self {
        Self { definition, fields: std::sync::Arc::from([]) }
    }

    pub fn definition(&self) -> u32 {
        self.definition
    }

    pub fn len(&self) -> usize {
        self.fields.len()
    }

    pub fn is_empty(&self) -> bool {
        self.fields.is_empty()
    }

    /// The fields the record sets, by id.
    pub fn fields(&self) -> impl Iterator<Item = (u32, &KiwiValue)> {
        self.fields.iter().map(|(id, value)| (*id, value))
    }

    pub fn get(&self, field: u32) -> Option<&KiwiValue> {
        self.position(field).ok().map(|index| &self.fields[index].1)
    }

    pub fn has(&self, field: u32) -> bool {
        self.position(field).is_ok()
    }

    /// The record a message or struct field holds.
    pub fn record(&self, field: u32) -> Option<&KiwiRecord> {
        match self.get(field) {
            Some(KiwiValue::Record(record)) => Some(record),
            _ => None,
        }
    }

    /// The values an array field holds; none when the field is unset.
    pub fn array(&self, field: u32) -> &[KiwiValue] {
        match self.get(field) {
            Some(KiwiValue::Array(values)) => values,
            _ => &[],
        }
    }

    /// The records an array field holds.
    pub fn records(&self, field: u32) -> Vec<&KiwiRecord> {
        self.array(field)
            .iter()
            .filter_map(|value| match value {
                KiwiValue::Record(record) => Some(record),
                _ => None,
            })
            .collect()
    }

    pub fn str(&self, field: u32) -> Option<&str> {
        match self.get(field) {
            Some(KiwiValue::String(value)) => Some(value),
            _ => None,
        }
    }

    pub fn bool(&self, field: u32) -> Option<bool> {
        match self.get(field) {
            Some(KiwiValue::Bool(value)) => Some(*value),
            _ => None,
        }
    }

    pub fn uint(&self, field: u32) -> Option<u32> {
        match self.get(field) {
            Some(KiwiValue::Uint(value)) => Some(*value),
            _ => None,
        }
    }

    pub fn int(&self, field: u32) -> Option<i32> {
        match self.get(field) {
            Some(KiwiValue::Int(value)) => Some(*value),
            _ => None,
        }
    }

    pub fn float(&self, field: u32) -> Option<f32> {
        match self.get(field) {
            Some(KiwiValue::Float(value)) => Some(*value),
            _ => None,
        }
    }

    /// An enum field's value.
    pub fn enum_value(&self, field: u32) -> Option<u32> {
        match self.get(field) {
            Some(KiwiValue::Enum(value, _definition)) => Some(*value),
            _ => None,
        }
    }

    /// The record with `field` set to `value`.
    pub fn put(&self, field: u32, value: KiwiValue) -> Self {
        let mut fields = self.fields.to_vec();
        match self.position(field) {
            Ok(index) => fields[index].1 = value,
            Err(index) => fields.insert(index, (field, value)),
        }
        self.with_fields(fields)
    }

    /// The record with `field` holding `record`.
    pub fn put_record(&self, field: u32, record: KiwiRecord) -> Self {
        self.put(field, KiwiValue::Record(record))
    }

    /// The record with `field` holding `value` of the enum defined at `definition`.
    pub fn put_enum(&self, field: u32, value: u32, definition: u32) -> Self {
        self.put(field, KiwiValue::Enum(value, definition))
    }

    /// The record with array `field` holding `records`.
    pub fn put_records(&self, field: u32, records: Vec<KiwiRecord>) -> Self {
        self.put(field, KiwiValue::Array(records.into_iter().map(KiwiValue::Record).collect()))
    }

    /// The record with each record in array `field` replaced by `update` of it. A record that
    /// does not set the field is returned as it is.
    pub fn map_records(&self, field: u32, update: impl Fn(&KiwiRecord) -> KiwiRecord) -> Self {
        match self.get(field) {
            Some(KiwiValue::Array(values)) => {
                let values = values
                    .iter()
                    .map(|value| match value {
                        KiwiValue::Record(record) => KiwiValue::Record(update(record)),
                        other => other.clone(),
                    })
                    .collect();
                self.put(field, KiwiValue::Array(values))
            }
            _ => self.clone(),
        }
    }

    /// The record with the record in `field` replaced by `update` of it, when it has one.
    pub fn map_record(&self, field: u32, update: impl Fn(&KiwiRecord) -> KiwiRecord) -> Self {
        match self.record(field) {
            Some(record) => self.put_record(field, update(record)),
            None => self.clone(),
        }
    }

    /// The record without `field`.
    pub fn delete(&self, field: u32) -> Self {
        match self.position(field) {
            Ok(index) => {
                let mut fields = self.fields.to_vec();
                fields.remove(index);
                self.with_fields(fields)
            }
            Err(_) => self.clone(),
        }
    }

    /// The record with every field `other` sets taken from `other`.
    pub fn merge(&self, other: &Self) -> Self {
        if other.is_empty() {
            return self.clone();
        }
        if self.is_empty() {
            return Self { definition: self.definition, fields: other.fields.clone() };
        }

        let mut fields = Vec::with_capacity(self.len() + other.len());
        let (mut left, mut right) = (self.fields.iter().peekable(), other.fields.iter().peekable());
        loop {
            match (left.peek(), right.peek()) {
                (Some((a, _)), Some((b, _))) if a < b => fields.push(left.next().unwrap().clone()),
                (Some((a, _)), Some((b, _))) if a == b => {
                    left.next();
                    fields.push(right.next().unwrap().clone());
                }
                (_, Some(_)) => fields.push(right.next().unwrap().clone()),
                (Some(_), None) => fields.push(left.next().unwrap().clone()),
                (None, None) => break,
            }
        }
        self.with_fields(fields)
    }

    /// The record keeping only `fields`.
    pub fn take(&self, fields: &[u32]) -> Self {
        self.with_fields(self.fields.iter().filter(|(id, _)| fields.contains(id)).cloned().collect())
    }

    /// The record without `fields`.
    pub fn drop(&self, fields: &[u32]) -> Self {
        if !self.fields.iter().any(|(id, _)| fields.contains(id)) {
            return self.clone();
        }
        self.with_fields(self.fields.iter().filter(|(id, _)| !fields.contains(id)).cloned().collect())
    }

    fn position(&self, field: u32) -> Result<usize, usize> {
        self.fields.binary_search_by_key(&field, |(id, _)| *id)
    }

    fn with_fields(&self, fields: Vec<(u32, KiwiValue)>) -> Self {
        Self { definition: self.definition, fields: fields.into() }
    }
}

/// The id of the field named `name` (its decoded-map key) in `definition`.
pub fn kiwi_record_field(definition: u32, name: &str) -> Option<u32> {
    KIWI_RECORD_DEFINITIONS
        .get(definition as usize)?
        .fields
        .iter()
        .find(|field| field.name == name)
        .map(|field| field.id)
}

/// Decodes a record of `definition`. Message fields the schema does not define are skipped
/// through the decoder's runtime schema, as generated decoders skip them.
pub fn kiwi_decode_record(decoder: &mut Decoder<'_>, definition: u32) -> NifResult<KiwiRecord> {
    kiwi_decode_record_at(decoder, definition, 0)
}

fn kiwi_decode_record_at(decoder: &mut Decoder<'_>, index: u32, depth: usize) -> NifResult<KiwiRecord> {
    if depth > KIWI_RECORD_MAX_DEPTH {
        return Err(Error::BadArg);
    }

    let definition = &KIWI_RECORD_DEFINITIONS[index as usize];
    let mut fields = Vec::new();

    if definition.kind == KIWI_RECORD_STRUCT {
        fields.reserve_exact(definition.fields.len());
        for field in definition.fields {
            fields.push((field.id, kiwi_decode_field(decoder, field, depth)?));
        }
    } else {
        loop {
            let id = decoder.read_var_uint()?;
            if id == 0 {
                break;
            }
            match definition.fields.binary_search_by_key(&id, |field| field.id) {
                Ok(position) => {
                    let value = kiwi_decode_field(decoder, &definition.fields[position], depth)?;
                    fields.push((id, value));
                }
                Err(_) => kiwi_unknown_field(decoder, definition.name, id)?,
            }
        }
        fields.sort_by_key(|(id, _)| *id);
    }

    Ok(KiwiRecord { definition: index, fields: fields.into() })
}

fn kiwi_decode_field(decoder: &mut Decoder<'_>, field: &KiwiRecordField, depth: usize) -> NifResult<KiwiValue> {
    if !field.array {
        return kiwi_decode_value(decoder, field.type_index, depth);
    }

    if field.type_index == KIWI_RECORD_BYTE {
        return Ok(KiwiValue::Bytes(decoder.read_byte_array_value()?.into()));
    }

    let count = decoder.read_var_uint()? as usize;
    let mut values = Vec::with_capacity(count.min(decoder.remaining()));
    for _ in 0..count {
        values.push(kiwi_decode_value(decoder, field.type_index, depth)?);
    }
    Ok(KiwiValue::Array(values.into()))
}

fn kiwi_decode_value(decoder: &mut Decoder<'_>, type_index: i32, depth: usize) -> NifResult<KiwiValue> {
    if type_index < 0 {
        return Ok(match !type_index {
            0 => KiwiValue::Bool(decoder.read_bool()?),
            1 => KiwiValue::Byte(decoder.read_byte()?),
            2 => KiwiValue::Int(decoder.read_var_int()?),
            3 => KiwiValue::Uint(decoder.read_var_uint()?),
            4 => KiwiValue::Float(decoder.read_var_float_value()?),
            5 => KiwiValue::String(decoder.read_string_str()?.into()),
            6 => KiwiValue::Int64(decoder.read_var_int64()?),
            _ => KiwiValue::Uint64(decoder.read_var_uint64()?),
        });
    }

    let index = type_index as u32;
    if KIWI_RECORD_DEFINITIONS[index as usize].kind == KIWI_RECORD_ENUM {
        Ok(KiwiValue::Enum(decoder.read_var_uint()?, index))
    } else {
        kiwi_decode_record_at(decoder, index, depth + 1).map(KiwiValue::Record)
    }
}

/// Encodes a record as the sparse map generated decoders return.
pub fn kiwi_encode_record<'a>(env: Env<'a>, record: &KiwiRecord) -> NifResult<Term<'a>> {
    kiwi_encode_record_fields(env, record, None)
}

/// Encodes a record as a sparse map holding only `only` of its fields, when given.
pub fn kiwi_encode_record_fields<'a>(
    env: Env<'a>,
    record: &KiwiRecord,
    only: Option<&[u32]>,
) -> NifResult<Term<'a>> {
    let definition = &KIWI_RECORD_DEFINITIONS[record.definition as usize];
    let mut keys = Vec::with_capacity(record.len() + 1);
    let mut values = Vec::with_capacity(record.len() + 1);
    keys.push(kiwi_atom(env, "__kiwi_module__").encode(env));
    values.push(kiwi_atom(env, definition.module).encode(env));

    for (id, value) in record.fields() {
        if only.is_some_and(|only| !only.contains(&id)) {
            continue;
        }
        let position = definition
            .fields
            .binary_search_by_key(&id, |field| field.id)
            .map_err(|_| Error::BadArg)?;
        keys.push(kiwi_atom(env, definition.fields[position].name).encode(env));
        values.push(kiwi_encode_value(env, value)?);
    }

    Term::map_from_term_arrays(env, &keys, &values)
}

fn kiwi_encode_value<'a>(env: Env<'a>, value: &KiwiValue) -> NifResult<Term<'a>> {
    Ok(match value {
        KiwiValue::Bool(value) => value.encode(env),
        KiwiValue::Byte(value) => value.encode(env),
        KiwiValue::Int(value) => value.encode(env),
        KiwiValue::Uint(value) => value.encode(env),
        KiwiValue::Float(value) => kiwi_encode_float(env, *value),
        KiwiValue::String(value) => value.as_ref().encode(env),
        KiwiValue::Int64(value) => value.encode(env),
        KiwiValue::Uint64(value) => value.encode(env),
        KiwiValue::Enum(value, definition) => {
            let variants = KIWI_RECORD_DEFINITIONS[*definition as usize].variants;
            match variants.binary_search_by_key(value, |variant| variant.value) {
                Ok(index) => kiwi_atom(env, variants[index].name).encode(env),
                Err(_) => value.encode(env),
            }
        }
        KiwiValue::Bytes(bytes) => {
            let mut binary = rustler::NewBinary::new(env, bytes.len());
            binary.as_mut_slice().copy_from_slice(bytes);
            Term::from(binary)
        }
        KiwiValue::Record(record) => kiwi_encode_record(env, record)?,
        KiwiValue::Array(values) => values
            .iter()
            .map(|value| kiwi_encode_value(env, value))
            .collect::<NifResult<Vec<_>>>()?
            .encode(env),
    })
}

/// Non-finite floats encode as the atoms Kiwi's Elixir decoder uses for them.
fn kiwi_encode_float<'a>(env: Env<'a>, value: f32) -> Term<'a> {
    if value.is_nan() {
        kiwi_atom(env, "nan").encode(env)
    } else if value == f32::INFINITY {
        kiwi_atom(env, "infinity").encode(env)
    } else if value == f32::NEG_INFINITY {
        kiwi_atom(env, "negative_infinity").encode(env)
    } else {
        (value as f64).encode(env)
    }
}
