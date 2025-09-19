import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings using shared preferences.
class SettingsService {
  static const String _minFrequencyKey = 'min_frequency';
  static const String _maxFrequencyKey = 'max_frequency';
  static const String _volumeKey = 'volume';

  // Default values
  static const double _defaultMinFrequency = 8000.0;
  static const double _defaultMaxFrequency = 14000.0;
  static const double _defaultVolume = -12.0;

  /// Get the minimum frequency setting.
  Future<double> getMinFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_minFrequencyKey) ?? _defaultMinFrequency;
  }

  /// Set the minimum frequency setting.
  Future<void> setMinFrequency(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_minFrequencyKey, value);
  }

  /// Get the maximum frequency setting.
  Future<double> getMaxFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_maxFrequencyKey) ?? _defaultMaxFrequency;
  }

  /// Set the maximum frequency setting.
  Future<void> setMaxFrequency(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_maxFrequencyKey, value);
  }

  /// Get the volume setting (in dB).
  Future<double> getVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_volumeKey) ?? _defaultVolume;
  }

  /// Set the volume setting (in dB).
  Future<void> setVolume(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, value);
  }

  /// Load all settings at once.
  Future<Map<String, double>> loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'minFrequency': prefs.getDouble(_minFrequencyKey) ?? _defaultMinFrequency,
      'maxFrequency': prefs.getDouble(_maxFrequencyKey) ?? _defaultMaxFrequency,
      'volume': prefs.getDouble(_volumeKey) ?? _defaultVolume,
    };
  }
}
