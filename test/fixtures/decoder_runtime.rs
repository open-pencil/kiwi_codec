use rustler::{Env, NifResult, Term};

pub struct Decoder<'a> {
    data: &'a [u8],
}

impl<'a> Decoder<'a> {
    pub fn read_bool(&mut self) -> NifResult<bool> {
        Ok(false)
    }

    pub fn read_byte(&mut self) -> NifResult<u8> {
        Ok(0)
    }

    pub fn read_var_float_value(&mut self) -> NifResult<f32> {
        Ok(0.0)
    }

    pub fn read_var_int(&mut self) -> NifResult<i32> {
        Ok(0)
    }

    pub fn read_var_int64(&mut self) -> NifResult<i64> {
        Ok(0)
    }

    pub fn skip_string(&mut self) -> NifResult<()> {
        Ok(())
    }

    pub fn read_var_uint(&mut self) -> NifResult<u32> {
        Ok(0)
    }

    pub fn read_var_uint64(&mut self) -> NifResult<u64> {
        Ok(0)
    }

    pub fn skip_byte_array(&mut self) -> NifResult<()> {
        Ok(())
    }

    pub fn read_repeated<T, F>(&mut self, _read: F) -> NifResult<Vec<T>>
    where
        F: FnMut(&mut Self) -> NifResult<T>,
    {
        Ok(Vec::new())
    }

    pub fn read_var_float<'b>(&mut self, _env: Env<'b>) -> NifResult<Term<'b>> {
        todo!()
    }

    pub fn read_byte_array<'b>(&mut self, _env: Env<'b>) -> NifResult<Term<'b>> {
        todo!()
    }

    pub fn read_string<'b>(&mut self, _env: Env<'b>) -> NifResult<Term<'b>> {
        todo!()
    }
}
