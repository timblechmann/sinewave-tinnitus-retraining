use std::sync::Arc;
use std::sync::atomic::{AtomicU32, Ordering};

pub trait AudioBackend: Send + Sync {
    fn start(&mut self, f: Box<dyn FnMut(&mut [f32]) + Send + 'static>);
    fn stop(&mut self);
}

pub struct AudioPlayer {
    backend: Box<dyn AudioBackend>,
    linear_gain: Arc<AtomicU32>,
    min_midi_note: Arc<AtomicU32>,
    max_midi_note: Arc<AtomicU32>,
}

impl AudioPlayer {
    pub fn new() -> Self {
        let initial_gain_db = -12.0;
        let initial_linear_gain = 10.0_f32.powf(initial_gain_db / 20.0);
        // Default frequency range: A4 (440Hz) to ~8000Hz
        let initial_min_midi = 69.0_f32.to_bits(); // A4
        let initial_max_midi = 115.0_f32.to_bits(); // ~8000Hz

        #[cfg(target_os = "android")]
        {
            Self {
                backend: Box::new(aaudio_backend::AAudioBackend::new()),
                linear_gain: Arc::new(AtomicU32::new(initial_linear_gain.to_bits())),
                min_midi_note: Arc::new(AtomicU32::new(initial_min_midi)),
                max_midi_note: Arc::new(AtomicU32::new(initial_max_midi)),
            }
        }
        #[cfg(not(target_os = "android"))]
        {
            Self {
                backend: Box::new(cpal_backend::CpalBackend::new()),
                linear_gain: Arc::new(AtomicU32::new(initial_linear_gain.to_bits())),
                min_midi_note: Arc::new(AtomicU32::new(initial_min_midi)),
                max_midi_note: Arc::new(AtomicU32::new(initial_max_midi)),
            }
        }
    }

    pub fn start(&mut self) {
        let mut audio_state = crate::AudioState::new(
            44100.0,
            self.linear_gain.clone(),
            self.min_midi_note.clone(),
            self.max_midi_note.clone(),
        );
        self.backend.start(Box::new(move |data| {
            audio_state.fill(data);
        }));
    }

    pub fn stop(&mut self) {
        self.backend.stop();
    }

    pub fn set_gain_db(&self, gain_db: f32) {
        let linear_gain = 10.0_f32.powf(gain_db / 20.0);
        self.linear_gain
            .store(linear_gain.to_bits(), Ordering::Relaxed);
    }

    pub fn set_frequency_range(&self, min_midi_note: f32, max_midi_note: f32) {
        self.min_midi_note
            .store(min_midi_note.to_bits(), Ordering::Relaxed);
        self.max_midi_note
            .store(max_midi_note.to_bits(), Ordering::Relaxed);
    }
}

#[cfg(target_os = "android")]
mod aaudio_backend;

#[cfg(not(target_os = "android"))]
mod cpal_backend;
