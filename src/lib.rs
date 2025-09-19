use rand::Rng;
use std::slice::ChunksMut;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU32, Ordering};
mod audio;

mod oscillator;

mod taus88;
use crate::taus88::SeedableRng;
use crate::taus88::Taus88;

use audio::AudioPlayer;

// Global audio player instance for JNI
static AUDIO_PLAYER: Mutex<Option<Box<AudioPlayer>>> = Mutex::new(None);

const FADE_SAMPLES: u64 = 64;

#[derive(PartialEq, Copy, Clone)]
enum AudioPhase {
    FadingIn,
    Playing,
    FadingOut,
    Paused,
}

struct SoundParams {
    freq: f32,
    duration_samples: u64,
}

struct SilenceParams {
    duration_samples: u64,
}

enum SegmentParams {
    Sound(SoundParams),
    Silence(SilenceParams),
}

pub struct AudioState {
    oscillator: oscillator::Oscillator,
    tone_samples_left: u64,
    pause_samples_left: u64,
    rng: Taus88,
    sample_rate: f32,
    state: AudioPhase,
    fade_samples_left: u64,
    linear_gain: Arc<AtomicU32>,
    min_midi_note: Arc<AtomicU32>,
    max_midi_note: Arc<AtomicU32>,
}

impl AudioState {
    pub fn new(
        sample_rate: f32,
        linear_gain: Arc<AtomicU32>,
        min_midi_note: Arc<AtomicU32>,
        max_midi_note: Arc<AtomicU32>,
    ) -> Self {
        Self {
            oscillator: oscillator::Oscillator::new(sample_rate),
            tone_samples_left: 0,
            pause_samples_left: (sample_rate * 0.5) as u64, // Start with 500ms silence
            rng: Taus88::from_seed([0; 12]),
            sample_rate,
            state: AudioPhase::Paused,
            fade_samples_left: 0,
            linear_gain,
            min_midi_note,
            max_midi_note,
        }
    }

    fn fill(&mut self, data: &mut [f32]) {
        let frames = data.chunks_mut(2);

        let no_new_segment_needed = (self.state == AudioPhase::Paused
            && self.pause_samples_left >= frames.len() as u64)
            || (self.state == AudioPhase::Playing && self.tone_samples_left >= frames.len() as u64);
        if no_new_segment_needed {
            self.fill_without_segment_change(frames)
        } else {
            self.fill_with_segment_change(frames)
        }
    }

    fn fill_with_segment_change(&mut self, data: ChunksMut<f32>) {
        let linear_gain = f32::from_bits(self.linear_gain.load(Ordering::Relaxed));

        for frame in data {
            let needs_new_segment = (self.state == AudioPhase::Paused
                && self.pause_samples_left == 0)
                || (self.state == AudioPhase::FadingOut && self.fade_samples_left == 0);

            if needs_new_segment {
                let min_midi = f32::from_bits(self.min_midi_note.load(Ordering::Relaxed));
                let max_midi = f32::from_bits(self.max_midi_note.load(Ordering::Relaxed));
                let params =
                    Self::randomize_params(&mut self.rng, self.sample_rate, min_midi, max_midi);
                match params {
                    SegmentParams::Sound(p) => {
                        self.oscillator.set_freq(p.freq, FADE_SAMPLES as u32);
                        self.tone_samples_left = p.duration_samples;
                        self.state = AudioPhase::FadingIn;
                        self.fade_samples_left = FADE_SAMPLES;
                    }
                    SegmentParams::Silence(p) => {
                        self.pause_samples_left = p.duration_samples;
                        self.state = AudioPhase::Paused;
                    }
                }
            } else if self.state == AudioPhase::FadingIn && self.fade_samples_left == 0 {
                self.state = AudioPhase::Playing;
            } else if self.state == AudioPhase::Playing && self.tone_samples_left == 0 {
                self.state = AudioPhase::FadingOut;
                self.fade_samples_left = FADE_SAMPLES;
            }

            let value = match self.state {
                AudioPhase::Paused => {
                    self.pause_samples_left -= 1;
                    0.0
                }
                AudioPhase::FadingIn => {
                    // Linear ramp from 0 to 1
                    let fade_progress =
                        (FADE_SAMPLES - self.fade_samples_left) as f32 / (FADE_SAMPLES - 1) as f32;
                    let current_gain = linear_gain * fade_progress;
                    self.fade_samples_left -= 1;
                    self.oscillator.next_sample() * current_gain
                }
                AudioPhase::Playing => {
                    self.tone_samples_left -= 1;
                    self.oscillator.next_sample() * linear_gain
                }
                AudioPhase::FadingOut => {
                    // Linear ramp from 1 to 0
                    let fade_progress =
                        (self.fade_samples_left - 1) as f32 / (FADE_SAMPLES - 1) as f32;
                    let current_gain = linear_gain * fade_progress;
                    self.fade_samples_left -= 1;
                    self.oscillator.next_sample() * current_gain
                }
            };

            if frame.len() == 2 {
                frame[0] = 0.0; // Left channel
                frame[1] = value; // Right channel
            } else {
                frame[0] = value;
            }
        }
    }

    fn fill_without_segment_change(&mut self, data: ChunksMut<f32>) {
        let linear_gain = f32::from_bits(self.linear_gain.load(Ordering::Relaxed));

        match self.state {
            AudioPhase::Paused => {
                self.pause_samples_left -= data.len() as u64;
                for frame in data {
                    assert_eq!(frame.len(), 2);

                    frame[0] = 0.0; // Left channel
                    frame[1] = 0.0; // Right channel
                }
            }
            AudioPhase::Playing => {
                let to_consume = data.len().min(self.tone_samples_left as usize);
                self.tone_samples_left -= to_consume as u64;
                for frame in data {
                    assert_eq!(frame.len(), 2);

                    let value = self.oscillator.next_sample() * linear_gain;
                    frame[0] = 0.0; // Left channel
                    frame[1] = value; // Right channel
                }
            }
            _ => panic!("Invalid state in fill_without_segment_change"),
        }
    }
    fn randomize_params(
        rng: &mut Taus88,
        sample_rate: f32,
        min_midi: f32,
        max_midi: f32,
    ) -> SegmentParams {
        if rng.random::<f32>() < 0.1 {
            // 10% chance for silence
            let pause_ms = rng.random_range(150..=400);
            let duration_samples = (pause_ms as f32 / 1000.0 * sample_rate) as u64;
            SegmentParams::Silence(SilenceParams { duration_samples })
        } else {
            let midi = rng.random_range(min_midi as i32..=max_midi as i32);
            let freq = 440.0 * 2.0_f32.powf((midi as f32 - 69.0) / 12.0);
            let duration_ms = rng.random_range(150..=400);
            let duration_samples = (duration_ms as f32 / 1000.0 * sample_rate) as u64;
            SegmentParams::Sound(SoundParams {
                freq,
                duration_samples,
            })
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn set_gain_db(player: *mut AudioPlayer, gain_db: f32) {
    if !player.is_null() {
        unsafe { (*player).set_gain_db(gain_db) };
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn set_frequency_range(
    player: *mut AudioPlayer,
    min_midi_note: f32,
    max_midi_note: f32,
) {
    if !player.is_null() {
        unsafe { (*player).set_frequency_range(min_midi_note, max_midi_note) };
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn create_audio_player() -> *mut AudioPlayer {
    let player = Box::new(AudioPlayer::new());
    let ptr = Box::into_raw(player);
    ptr
}

#[unsafe(no_mangle)]
pub extern "C" fn start_audio_player(player: *mut AudioPlayer) {
    if !player.is_null() {
        unsafe { (*player).start() }
    } else {
        log::error!("player is null");
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn stop_audio_player(player: *mut AudioPlayer) {
    if !player.is_null() {
        unsafe { (*player).stop() }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn destroy_audio_player(player: *mut AudioPlayer) {
    if !player.is_null() {
        unsafe { drop(Box::from_raw(player)) }
    }
}

// JNI-compatible exports for Android service using global static
#[unsafe(no_mangle)]
pub extern "C" fn Java_org_klingt_tim_sinewaveTinnitusRetraining_service_AudioPlaybackService_create_1audio_1player()
-> i32 {
    let mut player_guard = AUDIO_PLAYER.lock().unwrap();
    if player_guard.is_some() {
        // Already created
        return 1;
    }

    *player_guard = Some(Box::new(AudioPlayer::new()));
    1 // Success
}

#[unsafe(no_mangle)]
pub extern "C" fn Java_org_klingt_tim_sinewaveTinnitusRetraining_service_AudioPlaybackService_start_1audio_1player()
-> i32 {
    let mut player_guard = AUDIO_PLAYER.lock().unwrap();
    if let Some(ref mut player) = *player_guard {
        player.start();
        1 // Success
    } else {
        0 // No player
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn Java_org_klingt_tim_sinewaveTinnitusRetraining_service_AudioPlaybackService_stop_1audio_1player()
-> i32 {
    let mut player_guard = AUDIO_PLAYER.lock().unwrap();
    if let Some(ref mut player) = *player_guard {
        player.stop();
        1 // Success
    } else {
        0 // No player
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn Java_org_klingt_tim_sinewaveTinnitusRetraining_service_AudioPlaybackService_destroy_1audio_1player()
-> i32 {
    let mut player_guard = AUDIO_PLAYER.lock().unwrap();
    *player_guard = None; // Drop the player
    1 // Success
}

#[unsafe(no_mangle)]
pub extern "C" fn Java_org_klingt_tim_sinewaveTinnitusRetraining_service_AudioPlaybackService_setGain(
    _env: *const (),
    _class: *const (),
    gain_db: f32,
) {
    let player_guard = AUDIO_PLAYER.lock().unwrap();
    if let Some(ref player) = *player_guard {
        player.set_gain_db(gain_db);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn Java_org_klingt_tim_sinewaveTinnitusRetraining_service_AudioPlaybackService_setFrequencyRange(
    _env: *const (),
    _class: *const (),
    min_midi_note: f32,
    max_midi_note: f32,
) {
    let player_guard = AUDIO_PLAYER.lock().unwrap();
    if let Some(ref player) = *player_guard {
        player.set_frequency_range(min_midi_note, max_midi_note);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;
    use std::time::Duration;

    #[test]
    #[ignore] // Run manually with: cargo test manual_test_play_sound -- --ignored
    fn manual_test_play_sound() {
        let mut player = AudioPlayer::new();
        player.start();
        thread::sleep(Duration::from_secs(10)); // Play for 10 seconds
        player.stop();
        // Manually verify sound output
        assert!(true);
    }

    #[test]
    fn test_audio_player() {
        let mut player = AudioPlayer::new();
        player.start();
        thread::sleep(Duration::from_millis(100)); // Brief play
        player.stop();
        // Should not panic
        assert!(true);
    }
}
