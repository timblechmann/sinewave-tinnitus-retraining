use crate::audio::AudioBackend;
use std::sync::OnceLock;

mod bindings {
    #![allow(non_upper_case_globals)]
    #![allow(non_camel_case_types)]
    #![allow(non_snake_case)]
    #![allow(dead_code)]
    #![allow(unsafe_op_in_unsafe_fn)]

    // Manually extracted definitions from AAudio bindings
    pub type aaudio_result_t = i32;
    pub type aaudio_data_callback_result_t = i32;

    pub const AAUDIO_OK: aaudio_result_t = 0;
    pub const AAUDIO_DIRECTION_OUTPUT: i32 = 0;
    pub const AAUDIO_FORMAT_PCM_FLOAT: i32 = 2;
    pub const AAUDIO_PERFORMANCE_MODE_POWER_SAVING: i32 = 11;
    pub const AAUDIO_SHARING_MODE_SHARED: i32 = 1;
    pub const AAUDIO_CONTENT_TYPE_MUSIC: i32 = 2;
    pub const AAUDIO_USAGE_MEDIA: i32 = 1;
    pub const AAUDIO_CALLBACK_RESULT_CONTINUE: aaudio_data_callback_result_t = 0;

    #[repr(C)]
    pub struct AAudioStreamStruct {
        _private: [u8; 0],
    }
    pub type AAudioStream = AAudioStreamStruct;

    #[repr(C)]
    pub struct AAudioStreamBuilderStruct {
        _private: [u8; 0],
    }
    pub type AAudioStreamBuilder = AAudioStreamBuilderStruct;

    pub type AAudioStream_dataCallback = ::std::option::Option<
        unsafe extern "C" fn(
            stream: *mut AAudioStream,
            userData: *mut ::std::os::raw::c_void,
            audioData: *mut ::std::os::raw::c_void,
            numFrames: i32,
        ) -> aaudio_data_callback_result_t,
    >;
}

static AAUDIO_LIB: OnceLock<Option<libloading::Library>> = OnceLock::new();

fn get_aaudio_lib() -> Option<&'static libloading::Library> {
    AAUDIO_LIB
        .get_or_init(|| unsafe { libloading::Library::new("libaaudio.so") }.ok())
        .as_ref()
}

macro_rules! aaudio_fn {
    ($name:ident, $sig:ty) => {
        #[allow(non_snake_case)]
        fn $name() -> Option<libloading::Symbol<'static, $sig>> {
            unsafe { get_aaudio_lib()?.get(stringify!($name).as_bytes()).ok() }
        }
    };
}

aaudio_fn!(
    AAudio_createStreamBuilder,
    unsafe extern "C" fn(*mut *mut bindings::AAudioStreamBuilder) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setDirection,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setSampleRate,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setChannelCount,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setFormat,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setBufferCapacityInFrames,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setPerformanceMode,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setSharingMode,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setContentType,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setUsage,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder, i32) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_setDataCallback,
    unsafe extern "C" fn(
        *mut bindings::AAudioStreamBuilder,
        bindings::AAudioStream_dataCallback,
        *mut std::ffi::c_void,
    ) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_openStream,
    unsafe extern "C" fn(
        *mut bindings::AAudioStreamBuilder,
        *mut *mut bindings::AAudioStream,
    ) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStreamBuilder_delete,
    unsafe extern "C" fn(*mut bindings::AAudioStreamBuilder) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStream_requestStart,
    unsafe extern "C" fn(*mut bindings::AAudioStream) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStream_requestStop,
    unsafe extern "C" fn(*mut bindings::AAudioStream) -> bindings::aaudio_result_t
);
aaudio_fn!(
    AAudioStream_close,
    unsafe extern "C" fn(*mut bindings::AAudioStream) -> bindings::aaudio_result_t
);

extern "C" fn data_callback(
    _stream: *mut bindings::AAudioStream,
    user_data: *mut std::ffi::c_void,
    audio_data: *mut std::ffi::c_void,
    num_frames: i32,
) -> i32 {
    unsafe {
        let backend = user_data as *mut AAudioBackend;
        if let Some(ref mut cb) = (*backend).callback {
            let num_samples = (num_frames * 2) as usize; // stereo
            let data = std::slice::from_raw_parts_mut(audio_data as *mut f32, num_samples);
            cb(data);
        }
        bindings::AAUDIO_CALLBACK_RESULT_CONTINUE as i32
    }
}

pub struct AAudioBackend {
    stream: Option<*mut bindings::AAudioStream>,
    callback: Option<Box<dyn FnMut(&mut [f32]) + Send + 'static>>,
}

impl AAudioBackend {
    pub fn new() -> Self {
        log::info!("AAudioBackend::new()");
        Self {
            stream: None,
            callback: None,
        }
    }
}

// Make AAudioBackend Send + Sync (required for static storage)
unsafe impl Send for AAudioBackend {}
unsafe impl Sync for AAudioBackend {}

impl AudioBackend for AAudioBackend {
    fn start(&mut self, f: Box<dyn FnMut(&mut [f32]) + Send + 'static>) {
        if self.stream.is_some() {
            return; // already running
        }

        self.callback = Some(Box::new(f));

        let mut builder: *mut bindings::AAudioStreamBuilder = std::ptr::null_mut();
        unsafe {
            let create_fn = match AAudio_createStreamBuilder() {
                Some(f) => f,
                None => {
                    log::error!("AAudio_createStreamBuilder not available");
                    return;
                }
            };
            if create_fn(&mut builder) != bindings::AAUDIO_OK {
                log::error!("Failed to create AAudio stream builder");
                return;
            }

            if let Some(set_dir_fn) = AAudioStreamBuilder_setDirection() {
                set_dir_fn(builder, bindings::AAUDIO_DIRECTION_OUTPUT as i32);
            }
            if let Some(set_rate_fn) = AAudioStreamBuilder_setSampleRate() {
                set_rate_fn(builder, 44100);
            }
            if let Some(set_ch_fn) = AAudioStreamBuilder_setChannelCount() {
                set_ch_fn(builder, 2);
            }
            if let Some(set_fmt_fn) = AAudioStreamBuilder_setFormat() {
                set_fmt_fn(builder, bindings::AAUDIO_FORMAT_PCM_FLOAT as i32);
            }
            if let Some(set_buf_fn) = AAudioStreamBuilder_setBufferCapacityInFrames() {
                set_buf_fn(builder, 2048);
            }
            if let Some(set_perf_fn) = AAudioStreamBuilder_setPerformanceMode() {
                set_perf_fn(builder, bindings::AAUDIO_PERFORMANCE_MODE_POWER_SAVING);
            }
            if let Some(set_sharing_fn) = AAudioStreamBuilder_setSharingMode() {
                set_sharing_fn(builder, bindings::AAUDIO_SHARING_MODE_SHARED);
            }
            if let Some(set_content_fn) = AAudioStreamBuilder_setContentType() {
                set_content_fn(builder, bindings::AAUDIO_CONTENT_TYPE_MUSIC);
            }
            if let Some(set_usage_fn) = AAudioStreamBuilder_setUsage() {
                set_usage_fn(builder, bindings::AAUDIO_USAGE_MEDIA);
            }
            if let Some(set_cb_fn) = AAudioStreamBuilder_setDataCallback() {
                set_cb_fn(
                    builder,
                    Some(data_callback),
                    self as *mut _ as *mut std::ffi::c_void,
                );
            }

            let mut stream: *mut bindings::AAudioStream = std::ptr::null_mut();
            let open_fn = match AAudioStreamBuilder_openStream() {
                Some(f) => f,
                None => {
                    log::error!("AAudioStreamBuilder_openStream not available");
                    if let Some(del_fn) = AAudioStreamBuilder_delete() {
                        del_fn(builder);
                    }
                    return;
                }
            };
            if open_fn(builder, &mut stream) != bindings::AAUDIO_OK {
                log::error!("Failed to open AAudio stream");
                if let Some(del_fn) = AAudioStreamBuilder_delete() {
                    del_fn(builder);
                }
                return;
            }

            if let Some(del_fn) = AAudioStreamBuilder_delete() {
                del_fn(builder);
            }

            let start_fn = match AAudioStream_requestStart() {
                Some(f) => f,
                None => {
                    log::error!("AAudioStream_requestStart not available");
                    if let Some(close_fn) = AAudioStream_close() {
                        close_fn(stream);
                    }
                    return;
                }
            };
            if start_fn(stream) != bindings::AAUDIO_OK {
                log::error!("Failed to start AAudio stream");
                if let Some(close_fn) = AAudioStream_close() {
                    close_fn(stream);
                }
                return;
            }

            self.stream = Some(stream);
        }
    }

    fn stop(&mut self) {
        if let Some(stream) = self.stream.take() {
            unsafe {
                if let Some(stop_fn) = AAudioStream_requestStop() {
                    stop_fn(stream);
                }
                if let Some(close_fn) = AAudioStream_close() {
                    close_fn(stream);
                }
            }
        }
        self.callback = None;
    }
}

impl Drop for AAudioBackend {
    fn drop(&mut self) {
        self.stop();
    }
}
