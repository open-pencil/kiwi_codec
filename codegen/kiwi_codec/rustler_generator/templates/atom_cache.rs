/// The atom for a schema name, interned once per process. Atoms are never freed, so a cached
/// atom stays valid across calls and threads; the names are static, so their address and length
/// identify them without hashing their text. Each scheduler thread keeps its own copy of the
/// atoms it has used, so a lookup takes no lock once that thread has seen the name.
fn kiwi_atom(env: Env<'_>, name: &'static str) -> Atom {
    type KiwiAtoms = std::collections::HashMap<(usize, usize), Atom, KiwiAtomHasher>;

    static SHARED: std::sync::OnceLock<std::sync::RwLock<KiwiAtoms>> = std::sync::OnceLock::new();

    thread_local! {
        static LOCAL: std::cell::RefCell<KiwiAtoms> = std::cell::RefCell::new(KiwiAtoms::default());
    }

    let key = (name.as_ptr() as usize, name.len());

    LOCAL.with(|local| {
        *local.borrow_mut().entry(key).or_insert_with(|| {
            let shared = SHARED.get_or_init(Default::default);
            let known = shared.read().ok().and_then(|atoms| atoms.get(&key).copied());

            known.unwrap_or_else(|| {
                let atom = Atom::from_str(env, name).unwrap();
                if let Ok(mut atoms) = shared.write() {
                    atoms.insert(key, atom);
                }
                atom
            })
        })
    })
}

/// Mixes a static name's address and length; the keys need no protection from collisions.
#[derive(Default)]
struct KiwiAtomHash(u64);

impl std::hash::Hasher for KiwiAtomHash {
    fn finish(&self) -> u64 {
        self.0
    }

    fn write(&mut self, bytes: &[u8]) {
        for byte in bytes {
            self.write_u64(u64::from(*byte));
        }
    }

    fn write_usize(&mut self, value: usize) {
        self.write_u64(value as u64);
    }

    fn write_u64(&mut self, value: u64) {
        self.0 = (self.0.rotate_left(5) ^ value).wrapping_mul(0x51_7c_c1_b7_27_22_0a_95);
    }
}

type KiwiAtomHasher = std::hash::BuildHasherDefault<KiwiAtomHash>;
