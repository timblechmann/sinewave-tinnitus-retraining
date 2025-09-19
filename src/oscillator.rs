const SINE_TABLE_SIZE: usize = 4096;
const TWO_PI: f32 = 2.0 * std::f32::consts::PI;
const PHASE_TO_INDEX_FACTOR: f32 = 1.0 / TWO_PI * SINE_TABLE_SIZE as f32;

include!(concat!(env!("OUT_DIR"), "/sine_table.rs"));

pub struct Oscillator {
    phase: f32,
    freq: f32,
    sample_rate: f32,
    phase_inc: f32,
    target_freq: f32,
    freq_interp_step: f32,
    freq_interp_samples_left: u32,
}

impl Oscillator {
    pub fn new(sample_rate: f32) -> Self {
        let mut x = Self {
            phase: 0.0,
            freq: 440.0,
            sample_rate,
            phase_inc: 0.0,
            target_freq: 440.0,
            freq_interp_step: 0.0,
            freq_interp_samples_left: 0,
        };
        x.set_freq(440.0, 0);
        x
    }

    pub fn set_freq(&mut self, freq: f32, interp_samples: u32) {
        if interp_samples == 0 {
            self.freq = freq;
            self.target_freq = freq;
            self.freq_interp_samples_left = 0;
            self.phase_inc = TWO_PI * self.freq / self.sample_rate;
        } else {
            self.target_freq = freq;
            self.freq_interp_samples_left = interp_samples;
            self.freq_interp_step = (self.target_freq - self.freq) / interp_samples as f32;
        }
    }

    pub fn next_sample(&mut self) -> f32 {
        if self.freq_interp_samples_left > 0 {
            self.freq += self.freq_interp_step;
            self.freq_interp_samples_left -= 1;
            if self.freq_interp_samples_left == 0 {
                self.freq = self.target_freq;
            }
            self.phase_inc = TWO_PI * self.freq / self.sample_rate;
        }

        let index_f = self.phase * PHASE_TO_INDEX_FACTOR;
        let index_1 = index_f as usize;
        let index_2 = index_1 + 1;
        let frac = index_f - index_1 as f32;
        let val_1 = SINE_TABLE[index_1];
        let val_2 = SINE_TABLE[index_2];
        let value = val_1 + frac * (val_2 - val_1);

        self.phase += self.phase_inc;
        if self.phase >= TWO_PI {
            self.phase -= TWO_PI;
        }

        value
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sine_table_size() {
        assert_eq!(SINE_TABLE.len(), SINE_TABLE_SIZE + 1);
    }

    #[test]
    fn test_sine_table_values() {
        // Check first value is 0
        assert!((SINE_TABLE[0] - 0.0).abs() < 1e-6);
        // Check quarter is 1
        assert!((SINE_TABLE[SINE_TABLE_SIZE / 4] - 1.0).abs() < 1e-6);
        // Check wraparound
        assert!((SINE_TABLE[SINE_TABLE_SIZE] - SINE_TABLE[0]).abs() < 1e-6);
    }

    #[test]
    fn test_oscillator_initialization() {
        let osc = Oscillator::new(44100.0);
        assert_eq!(osc.freq, 440.0);
    }

    #[test]
    fn test_oscillator_produces_samples() {
        let mut osc = Oscillator::new(44100.0);
        let sample = osc.next_sample();
        assert!(sample >= -1.0 && sample <= 1.0);
    }

    #[test]
    fn test_freq_interpolation() {
        let mut osc = Oscillator::new(44100.0);
        osc.set_freq(880.0, 10);
        assert_eq!(osc.target_freq, 880.0);
        assert_eq!(osc.freq_interp_samples_left, 10);
        assert_eq!(osc.freq, 440.0);

        for _ in 0..10 {
            osc.next_sample();
        }

        assert_eq!(osc.freq_interp_samples_left, 0);
        assert!((osc.freq - 880.0).abs() < 1e-3);
    }
}
