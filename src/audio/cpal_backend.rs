use crate::audio::AudioBackend;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Stream, StreamConfig};

pub struct CpalBackend {
    stream: Option<Stream>,
}

impl CpalBackend {
    pub fn new() -> Self {
        Self { stream: None }
    }
}

// Make CpalBackend Send + Sync (required for static storage)
unsafe impl Send for CpalBackend {}
unsafe impl Sync for CpalBackend {}

impl AudioBackend for CpalBackend {
    fn start(&mut self, mut f: Box<dyn FnMut(&mut [f32]) + Send + 'static>) {
        if self.stream.is_some() {
            return; // already running
        }

        let host = cpal::default_host();

        let device = match host.default_output_device() {
            Some(d) => d,
            None => {
                log::error!("No audio output device found");
                return;
            }
        };
        let config = StreamConfig {
            channels: 2,
            sample_rate: cpal::SampleRate(44100),
            buffer_size: cpal::BufferSize::Fixed(2048),
        };

        let stream = match device.build_output_stream(
            &config,
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                f(data);
            },
            move |err| {
                log::error!("audio error: {err}");
            },
            None,
        ) {
            Ok(s) => s,
            Err(e) => {
                log::error!("Failed to build audio stream: {}", e);
                return;
            }
        };

        if let Err(e) = stream.play() {
            log::error!("Failed to play audio stream: {}", e);
            return;
        }

        self.stream = Some(stream);
    }

    fn stop(&mut self) {
        self.stream.take(); // drops the stream
    }
}
