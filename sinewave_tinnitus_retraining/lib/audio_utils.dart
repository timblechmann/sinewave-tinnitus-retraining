import 'dart:math';

/// Utility functions for audio-related calculations.
class AudioUtils {
  /// Converts a slider value (0.0 to 1.0) to gain in dB.
  static double sliderToDb(double sliderValue) {
    if (sliderValue <= 0.0) return -60.0;
    if (sliderValue < 0.5) {
      // Exponential fade from -60 dB to -10 dB
      final t = sliderValue / 0.5;
      return -60.0 + (t * 50.0);
    } else {
      // Linear in dB from -10 dB to +10 dB
      final t = (sliderValue - 0.5) / 0.5;
      return -10.0 + (t * 20.0);
    }
  }

  /// Converts gain in dB back to slider position (0.0 to 1.0).
  static double dbToSlider(double dbValue) {
    if (dbValue <= -60.0) return 0.0;
    if (dbValue < -10.0) {
      // Inverse of lower half
      final t = (dbValue + 60.0) / 50.0;
      return t * 0.5;
    } else {
      // Inverse of upper half
      final t = (dbValue + 10.0) / 20.0;
      return 0.5 + (t * 0.5);
    }
  }

  /// Converts MIDI note number to frequency in Hz.
  static double midiNoteToFrequency(double midiNote) {
    return 440.0 * pow(2.0, (midiNote - 69.0) / 12.0);
  }

  /// Converts frequency in Hz to MIDI note number.
  static double frequencyToMidiNote(double frequency) {
    return 69.0 + 12.0 * log(frequency / 440.0) / log(2.0);
  }
}
