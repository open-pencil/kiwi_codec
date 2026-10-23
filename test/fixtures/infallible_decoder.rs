//! A `Decoder` whose `read_var_int64` cannot fail, unlike the reference one.

use rustler::NifResult;

pub struct Decoder<'a> {
    data: &'a [u8],
}

impl<'a> Decoder<'a> {
    pub fn read_var_uint(&mut self) -> NifResult<u32> {
        Ok(self.data.len() as u32)
    }

    pub fn read_var_int64(&mut self) -> i64 {
        self.data.len() as i64
    }
}
