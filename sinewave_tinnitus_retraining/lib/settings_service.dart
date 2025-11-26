import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings using shared preferences.
class SettingsService {
  static const String _minFrequencyKey = 'channel_right.min_frequency';
  static const String _maxFrequencyKey = 'channel_right.max_frequency';
  static const String _volumeKey = 'channel_right.volume';

  static const String _minFrequencyLeftKey = 'channel_left.min_frequency';
  static const String _maxFrequencyLeftKey = 'channel_left.max_frequency';
  static const String _volumeLeftKey = 'channel_left.volume';

  // Default values as MIDI note numbers
  // ~8000 Hz = MIDI note ~107.9
  // ~14000 Hz = MIDI note ~119.4
  static const double _defaultMinFrequency = 107.9;
  static const double _defaultMaxFrequency = 119.4;
  static const double _defaultVolume = -12.0;

  late final SharedPreferencesWithCache _prefs;

  /// Initialize the settings service.
  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {
          _minFrequencyKey,
          _maxFrequencyKey,
          _volumeKey,
          _minFrequencyLeftKey,
          _maxFrequencyLeftKey,
          _volumeLeftKey,
        },
      ),
    );
  }

  /// Get the minimum frequency setting (Right Channel / Default).
  double getMinFrequencyRight() {
    return _prefs.getDouble(_minFrequencyKey) ?? _defaultMinFrequency;
  }

  /// Get the maximum frequency setting (Right Channel / Default).
  double getMaxFrequencyRight() {
    return _prefs.getDouble(_maxFrequencyKey) ?? _defaultMaxFrequency;
  }

  /// Get the volume setting (in dB) (Right Channel / Default).
  double getVolumeRight() {
    return _prefs.getDouble(_volumeKey) ?? _defaultVolume;
  }

  /// Set the settings for the Right Channel.
  Future<void> setRightChannel(ChannelSettings settings) async {
    await _prefs.setDouble(_minFrequencyKey, settings.minFrequency);
    await _prefs.setDouble(_maxFrequencyKey, settings.maxFrequency);
    await _prefs.setDouble(_volumeKey, settings.volume);
  }

  // --- Left Channel Settings ---

  /// Get the minimum frequency setting (Left Channel).
  double getMinFrequencyLeft() {
    return _prefs.getDouble(_minFrequencyLeftKey) ?? _defaultMinFrequency;
  }

  /// Get the maximum frequency setting (Left Channel).
  double getMaxFrequencyLeft() {
    return _prefs.getDouble(_maxFrequencyLeftKey) ?? _defaultMaxFrequency;
  }

  /// Get the volume setting (in dB) (Left Channel).
  double getVolumeLeft() {
    return _prefs.getDouble(_volumeLeftKey) ?? _defaultVolume;
  }

  /// Set the settings for the Left Channel.
  Future<void> setLeftChannel(ChannelSettings settings) async {
    await _prefs.setDouble(_minFrequencyLeftKey, settings.minFrequency);
    await _prefs.setDouble(_maxFrequencyLeftKey, settings.maxFrequency);
    await _prefs.setDouble(_volumeLeftKey, settings.volume);
  }

  /// Load all settings at once.
  AppSettings loadAllSettings() {
    return AppSettings(
      leftChannel: ChannelSettings(
        minFrequency:
            _prefs.getDouble(_minFrequencyLeftKey) ?? _defaultMinFrequency,
        maxFrequency:
            _prefs.getDouble(_maxFrequencyLeftKey) ?? _defaultMaxFrequency,
        volume: _prefs.getDouble(_volumeLeftKey) ?? _defaultVolume,
      ),
      rightChannel: ChannelSettings(
        minFrequency:
            _prefs.getDouble(_minFrequencyKey) ?? _defaultMinFrequency,
        maxFrequency:
            _prefs.getDouble(_maxFrequencyKey) ?? _defaultMaxFrequency,
        volume: _prefs.getDouble(_volumeKey) ?? _defaultVolume,
      ),
    );
  }
}

/// Settings for a single audio channel.
///
/// Note: minFrequency and maxFrequency are stored as MIDI note numbers (28.0-131.0),
/// NOT as raw frequency values in Hz. Use AudioUtils.midiNoteToFrequency() to convert
/// to Hz for display purposes.
class ChannelSettings {
  /// Minimum frequency as a MIDI note number (e.g., 107.9 ≈ 8000 Hz)
  final double minFrequency;

  /// Maximum frequency as a MIDI note number (e.g., 119.4 ≈ 14000 Hz)
  final double maxFrequency;

  /// Volume in decibels (dB)
  final double volume;

  const ChannelSettings({
    required this.minFrequency,
    required this.maxFrequency,
    required this.volume,
  });

  ChannelSettings copyWith({
    double? minFrequency,
    double? maxFrequency,
    double? volume,
  }) {
    return ChannelSettings(
      minFrequency: minFrequency ?? this.minFrequency,
      maxFrequency: maxFrequency ?? this.maxFrequency,
      volume: volume ?? this.volume,
    );
  }
}

/// Global app settings containing settings for both channels.
class AppSettings {
  final ChannelSettings leftChannel;
  final ChannelSettings rightChannel;

  AppSettings({required this.leftChannel, required this.rightChannel});

  /// Create default settings with hardcoded values.
  factory AppSettings.defaultSettings() {
    // Default values as MIDI note numbers
    // ~8000 Hz = MIDI note ~107.9
    // ~14000 Hz = MIDI note ~119.4
    const defaultChannel = ChannelSettings(
      minFrequency: 107.9,
      maxFrequency: 119.4,
      volume: -12.0,
    );
    return AppSettings(
      leftChannel: defaultChannel,
      rightChannel: defaultChannel,
    );
  }

  AppSettings copyWith({
    ChannelSettings? leftChannel,
    ChannelSettings? rightChannel,
  }) {
    return AppSettings(
      leftChannel: leftChannel ?? this.leftChannel,
      rightChannel: rightChannel ?? this.rightChannel,
    );
  }
}
