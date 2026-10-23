//! A Kiwi `Decoder` satisfying the generated decoders' contract; see
//! `KiwiCodec.RustlerGenerator.Decoder`. The generator reads its method signatures, and the
//! tests build it with every generator feature.

use rustler::types::atom::Atom;
use rustler::{Encoder, Env, Error, NifResult, Term};

use crate::RuntimeSchema;

pub struct Decoder<'a> {
    data: &'a [u8],
    index: usize,
    runtime_schema: Option<&'a RuntimeSchema>,
}

#[allow(dead_code)]
impl<'a> Decoder<'a> {
    pub fn new(data: &'a [u8]) -> Self {
        Self::with_schema(data, None)
    }

    pub fn with_schema(data: &'a [u8], runtime_schema: Option<&'a RuntimeSchema>) -> Self {
        Self {
            data,
            index: 0,
            runtime_schema,
        }
    }

    pub fn runtime_schema(&self) -> Option<&'a RuntimeSchema> {
        self.runtime_schema
    }

    pub fn finish(&self) -> NifResult<()> {
        if self.index == self.data.len() {
            Ok(())
        } else {
            Err(Error::BadArg)
        }
    }

    pub fn remaining(&self) -> usize {
        self.data.len() - self.index
    }

    pub fn read_bool(&mut self) -> NifResult<bool> {
        match self.read_byte()? {
            0 => Ok(false),
            1 => Ok(true),
            _ => Err(Error::BadArg),
        }
    }

    pub fn read_byte(&mut self) -> NifResult<u8> {
        let byte = *self.data.get(self.index).ok_or(Error::BadArg)?;
        self.index += 1;
        Ok(byte)
    }

    pub fn read_var_uint(&mut self) -> NifResult<u32> {
        u32::try_from(self.read_var_uint64()?).map_err(|_| Error::BadArg)
    }

    pub fn read_var_uint64(&mut self) -> NifResult<u64> {
        let mut result = 0u64;
        for shift in (0..64).step_by(7) {
            let byte = self.read_byte()?;
            result |= ((byte & 0x7f) as u64) << shift;
            if byte < 0x80 {
                return Ok(result);
            }
        }
        Err(Error::BadArg)
    }

    pub fn read_var_int(&mut self) -> NifResult<i32> {
        let value = self.read_var_uint()?;
        Ok(((value >> 1) as i32) ^ -((value & 1) as i32))
    }

    pub fn read_var_int64(&mut self) -> NifResult<i64> {
        let value = self.read_var_uint64()?;
        Ok(((value >> 1) as i64) ^ -((value & 1) as i64))
    }

    pub fn read_var_float<'b>(&mut self, env: Env<'b>) -> NifResult<Term<'b>> {
        Ok(encode_float(env, self.read_var_float_value()?))
    }

    pub fn read_var_float_value(&mut self) -> NifResult<f32> {
        let first = self.read_byte()?;
        if first == 0 {
            return Ok(0.0);
        }
        let rest = self.read_bytes(3)?;
        let bits = u32::from_le_bytes([first, rest[0], rest[1], rest[2]]);
        Ok(f32::from_bits(bits.rotate_left(23)))
    }

    pub fn read_byte_array<'b>(&mut self, env: Env<'b>) -> NifResult<Term<'b>> {
        Ok(new_binary(env, self.read_byte_array_value()?))
    }

    pub fn read_byte_array_value(&mut self) -> NifResult<&'a [u8]> {
        let len = self.read_var_uint()? as usize;
        self.read_bytes(len)
    }

    pub fn skip_byte_array(&mut self) -> NifResult<()> {
        self.read_byte_array_value().map(|_| ())
    }

    pub fn read_string<'b>(&mut self, env: Env<'b>) -> NifResult<Term<'b>> {
        Ok(new_binary(env, self.read_string_str()?.as_bytes()))
    }

    pub fn read_string_str(&mut self) -> NifResult<&'a str> {
        let rest = &self.data[self.index..];
        let len = rest.iter().position(|&byte| byte == 0).ok_or(Error::BadArg)?;
        let string = std::str::from_utf8(&rest[..len]).map_err(|_| Error::BadArg)?;
        self.index += len + 1;
        Ok(string)
    }

    pub fn read_string_value(&mut self) -> NifResult<String> {
        self.read_string_str().map(str::to_owned)
    }

    pub fn skip_string(&mut self) -> NifResult<()> {
        self.read_string_str().map(|_| ())
    }

    pub fn read_repeated<T, F>(&mut self, mut read: F) -> NifResult<Vec<T>>
    where
        F: FnMut(&mut Self) -> NifResult<T>,
    {
        let len = self.read_var_uint()? as usize;
        let mut values = Vec::with_capacity(len.min(self.remaining()));
        for _ in 0..len {
            values.push(read(self)?);
        }
        Ok(values)
    }

    fn read_bytes(&mut self, len: usize) -> NifResult<&'a [u8]> {
        let end = self.index.checked_add(len).ok_or(Error::BadArg)?;
        let bytes = self.data.get(self.index..end).ok_or(Error::BadArg)?;
        self.index = end;
        Ok(bytes)
    }
}

fn new_binary<'b>(env: Env<'b>, bytes: &[u8]) -> Term<'b> {
    let mut binary = rustler::NewBinary::new(env, bytes.len());
    binary.as_mut_slice().copy_from_slice(bytes);
    binary.into()
}

/// Encodes a float the way `KiwiCodec` decodes it, with atoms for the values Erlang lacks.
fn encode_float(env: Env<'_>, value: f32) -> Term<'_> {
    let special = if value.is_nan() {
        Some("nan")
    } else if value == f32::INFINITY {
        Some("infinity")
    } else if value == f32::NEG_INFINITY {
        Some("negative_infinity")
    } else {
        None
    };

    match special {
        Some(name) => Atom::from_str(env, name).unwrap().encode(env),
        None => (value as f64).encode(env),
    }
}
