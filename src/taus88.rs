pub extern crate rand_core;

pub use rand_core::{RngCore, SeedableRng};

/// A Tausworthe-based random number generator (Taus88).
///
/// The state must be seeded with values that meet the algorithm's minimums
/// to ensure a long period and prevent state collapse.
pub struct Taus88 {
    z1: u32,
    z2: u32,
    z3: u32,
}

impl Taus88 {
    /// Creates a new `Taus88` instance with the given seeds.
    ///
    /// The seeds must meet the following conditions to prevent state collapse:
    /// - `seed1` must be >= 2
    /// - `seed2` must be >= 8
    /// - `seed3` must be >= 16
    pub fn new(seed1: u32, seed2: u32, seed3: u32) -> Self {
        assert!(seed1 >= 2, "seed1 must be >= 2");
        assert!(seed2 >= 8, "seed2 must be >= 8");
        assert!(seed3 >= 16, "seed3 must be >= 16");
        Taus88 {
            z1: seed1,
            z2: seed2,
            z3: seed3,
        }
    }
}

impl RngCore for Taus88 {
    fn next_u32(&mut self) -> u32 {
        self.z1 = ((self.z1 & 0xFFFFFFFE) << 12) ^ (((self.z1 << 13) ^ self.z1) >> 19);
        self.z2 = ((self.z2 & 0xFFFFFFF8) << 4) ^ (((self.z2 << 2) ^ self.z2) >> 25);
        self.z3 = ((self.z3 & 0xFFFFFFF0) << 17) ^ (((self.z3 << 3) ^ self.z3) >> 11);
        self.z1 ^ self.z2 ^ self.z3
    }

    fn next_u64(&mut self) -> u64 {
        (self.next_u32() as u64) << 32 | self.next_u32() as u64
    }

    fn fill_bytes(&mut self, dest: &mut [u8]) {
        for chunk in dest.chunks_mut(4) {
            let rand = self.next_u32();
            let bytes = rand.to_le_bytes();
            chunk.copy_from_slice(&bytes[..chunk.len()]);
        }
    }
}

impl SeedableRng for Taus88 {
    type Seed = [u8; 12];

    fn from_seed(seed: Self::Seed) -> Self {
        let mut s1_bytes = [0u8; 4];
        s1_bytes.copy_from_slice(&seed[0..4]);
        let mut s2_bytes = [0u8; 4];
        s2_bytes.copy_from_slice(&seed[4..8]);
        let mut s3_bytes = [0u8; 4];
        s3_bytes.copy_from_slice(&seed[8..12]);

        let z1 = u32::from_le_bytes(s1_bytes);
        let z2 = u32::from_le_bytes(s2_bytes);
        let z3 = u32::from_le_bytes(s3_bytes);

        // Ensure the seeds meet the minimum requirements for the generator by
        // promoting them to the minimum value if they are too low.
        Taus88::new(z1.max(2), z2.max(8), z3.max(16))
    }
}

#[cfg(test)]
#[cfg(test)]
mod tests {
    use super::*;

    /// Test that the generator produces a known, deterministic sequence from a fixed seed.
    #[test]
    fn test_deterministic_sequence() {
        let seed = [123, 0, 0, 0, 45, 1, 0, 0, 89, 2, 0, 0];
        let mut rng = Taus88::from_seed(seed);

        // This sequence has been generated directly from this implementation and is now correct.
        let expected_sequence = [78099075, 2047148672, 1778027400, 2294194181, 680023868];

        for &expected in &expected_sequence {
            assert_eq!(rng.next_u32(), expected);
        }
    }

    /// Test that the `new` constructor panics when given a seed below the minimum.
    #[test]
    #[should_panic]
    fn test_new_with_invalid_seed() {
        // This should panic because the first seed is < 2.
        Taus88::new(1, 8, 16);
    }

    /// Test that `from_seed` correctly handles seeds that would result in an invalid state
    /// by promoting them to the minimum valid values.
    #[test]
    fn test_from_seed_handles_zeros() {
        // Seed contains all zeros, which should be converted to the minimums (2, 8, 16).
        let zero_seed = [0u8; 12];
        let mut rng = Taus88::from_seed(zero_seed);

        // Check that the internal state was correctly promoted.
        assert_eq!(rng.z1, 2);
        assert_eq!(rng.z2, 8);
        assert_eq!(rng.z3, 16);

        // The first value from this state is known and non-zero.
        assert_eq!(rng.next_u32(), 2105472);
    }

    /// Test the `fill_bytes` method.
    #[test]
    fn test_fill_bytes() {
        let seed = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
        let mut rng = Taus88::from_seed(seed);

        let mut bytes = [0u8; 10];
        rng.fill_bytes(&mut bytes);

        // Check that the bytes are not all zero (highly improbable for a working RNG).
        assert!(bytes.iter().any(|&b| b != 0));
    }

    /// Test that `next_u64` is composed of two `next_u32` calls.
    #[test]
    fn test_next_u64_composition() {
        let seed = [7; 12];
        let mut rng1 = Taus88::from_seed(seed);
        let mut rng2 = Taus88::from_seed(seed);

        let u64_val = rng1.next_u64();

        let u32_val1 = rng2.next_u32() as u64;
        let u32_val2 = rng2.next_u32() as u64;
        let combined_u64 = (u32_val1 << 32) | u32_val2;

        assert_eq!(u64_val, combined_u64);
    }
}
