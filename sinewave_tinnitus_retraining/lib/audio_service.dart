import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

// FFI function signatures
typedef _CreateAudioPlayerC = Pointer Function();
typedef _CreateAudioPlayerDart = Pointer Function();

typedef _VoidPlayerFnC = Void Function(Pointer);
typedef _VoidPlayerFnDart = void Function(Pointer);

typedef _SetGainFnC = Void Function(Pointer, Float);
typedef _SetGainFnDart = void Function(Pointer, double);

typedef _SetFrequencyRangeFnC = Void Function(Pointer, Float, Float);
typedef _SetFrequencyRangeFnDart = void Function(Pointer, double, double);

abstract class AudioService {
  factory AudioService() {
    if (Platform.isAndroid) {
      return MobileAudioService();
    } else if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return DesktopAudioService();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  Future<void> init();
  Future<void> start();
  Future<void> stop();
  Future<void> setGain(double gainDb);
  Future<void> setFrequencyRange(double minMidiNote, double maxMidiNote);
  Future<bool> isPlaying();
  void dispose();
}

class MobileAudioService implements AudioService {
  static const _platform = MethodChannel(
    'org.klingt.tim.sinewaveTinnitusRetraining/audio_service',
  );

  bool _isPlaying = false;

  @override
  Future<void> init() async {
    try {
      final bool? isPlaying = await _platform.invokeMethod('getPlaybackState');
      if (isPlaying != null) {
        _isPlaying = isPlaying;
      }
    } on PlatformException {
      // Error handled in caller
    }
  }

  @override
  Future<void> start() async {
    try {
      await _platform.invokeMethod('startAudioService');
      _isPlaying = true;
    } on PlatformException {
      // Error handled in caller
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _platform.invokeMethod('stopAudioService');
      _isPlaying = false;
    } on PlatformException {
      // Error handled in caller
    }
  }

  @override
  Future<void> setGain(double gainDb) async {
    try {
      await _platform.invokeMethod('setGain', {'gain': gainDb});
    } on PlatformException {
      // Error handled in caller
    }
  }

  @override
  Future<void> setFrequencyRange(double minMidiNote, double maxMidiNote) async {
    try {
      await _platform.invokeMethod('setFrequencyRange', {
        'minMidiNote': minMidiNote,
        'maxMidiNote': maxMidiNote,
      });
    } on PlatformException {
      // Error handled in caller
    }
  }

  @override
  Future<bool> isPlaying() async => _isPlaying;

  @override
  void dispose() {
    // For mobile, the service lifecycle is handled by the OS
  }
}

class DesktopAudioService implements AudioService {
  late final _CreateAudioPlayerDart _createAudioPlayer;
  late final _VoidPlayerFnDart _startAudioPlayer;
  late final _VoidPlayerFnDart _stopAudioPlayer;
  late final _VoidPlayerFnDart _destroyAudioPlayer;
  late final _SetGainFnDart _setGainDb;
  late final _SetFrequencyRangeFnDart _setFrequencyRange;

  Pointer? _playerPtr;
  bool _isPlaying = false;

  DesktopAudioService() {
    try {
      final dylib = DynamicLibrary.open(
        '../Frameworks/libsinewave_tinnitus_retraining_audio_core.dylib',
      );
      _createAudioPlayer = dylib
          .lookup<NativeFunction<_CreateAudioPlayerC>>('create_audio_player')
          .asFunction();
      _startAudioPlayer = dylib
          .lookup<NativeFunction<_VoidPlayerFnC>>('start_audio_player')
          .asFunction();
      _stopAudioPlayer = dylib
          .lookup<NativeFunction<_VoidPlayerFnC>>('stop_audio_player')
          .asFunction();
      _destroyAudioPlayer = dylib
          .lookup<NativeFunction<_VoidPlayerFnC>>('destroy_audio_player')
          .asFunction();
      _setGainDb = dylib
          .lookup<NativeFunction<_SetGainFnC>>('set_gain_db')
          .asFunction();
      _setFrequencyRange = dylib
          .lookup<NativeFunction<_SetFrequencyRangeFnC>>('set_frequency_range')
          .asFunction();
    } catch (e) {
      print('Failed to load dynamic library: $e');
      rethrow;
    }
  }

  @override
  Future<void> init() async {
    _playerPtr ??= _createAudioPlayer();
  }

  @override
  Future<void> start() async {
    if (_playerPtr != null) {
      _startAudioPlayer(_playerPtr!);
      _isPlaying = true;
    }
  }

  @override
  Future<void> stop() async {
    if (_playerPtr != null) {
      _stopAudioPlayer(_playerPtr!);
      _isPlaying = false;
    }
  }

  @override
  Future<void> setGain(double gainDb) async {
    if (_playerPtr != null) {
      _setGainDb(_playerPtr!, gainDb);
    }
  }

  @override
  Future<void> setFrequencyRange(double minMidiNote, double maxMidiNote) async {
    if (_playerPtr != null) {
      _setFrequencyRange(_playerPtr!, minMidiNote, maxMidiNote);
    }
  }

  @override
  Future<bool> isPlaying() async => _isPlaying;

  @override
  void dispose() {
    if (_playerPtr != null) {
      _destroyAudioPlayer(_playerPtr!);
      _playerPtr = null;
    }
  }
}
