import 'package:flutter/foundation.dart';
import 'audio_service.dart';
import 'settings_service.dart';

class SettingsController {
  final SettingsService _settingsService;
  final AudioService _audioService;

  late final ValueNotifier<AppSettings> settings;

  SettingsController(this._settingsService, this._audioService) {
    // Initialize with default settings to avoid LateInitializationError
    settings = ValueNotifier(AppSettings.defaultSettings());
  }

  Future<void> init() async {
    await _settingsService.init();
    final initialSettings = _settingsService.loadAllSettings();
    // Update the existing ValueNotifier instead of creating a new one
    settings.value = initialSettings;
  }

  Future<void> updateRightChannel(ChannelSettings newSettings) async {
    // Update state
    settings.value = settings.value.copyWith(rightChannel: newSettings);

    // Update Audio Service
    // Note: settings already store MIDI notes, not frequencies
    await _audioService.setGain(newSettings.volume);
    await _audioService.setFrequencyRange(
      newSettings.minFrequency, // Already a MIDI note
      newSettings.maxFrequency, // Already a MIDI note
    );

    // Persist Settings
    await _settingsService.setRightChannel(newSettings);
  }

  Future<void> updateLeftChannel(ChannelSettings newSettings) async {
    // Update state
    settings.value = settings.value.copyWith(leftChannel: newSettings);

    // Persist Settings (No Audio Service update for Left Channel)
    await _settingsService.setLeftChannel(newSettings);
  }

  void dispose() {
    settings.dispose();
  }
}
