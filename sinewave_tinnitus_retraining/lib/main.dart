import 'package:flutter/material.dart';

import 'audio_service.dart';
import 'audio_utils.dart';
import 'platform_utils.dart';
import 'settings_service.dart';
import 'tray_manager.dart';
import 'window_manager_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SinewaveTinnitusRetrainingApp());
}

class SinewaveTinnitusRetrainingApp extends StatelessWidget {
  const SinewaveTinnitusRetrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinewave Tinnitus Retraining',
      theme: ThemeData(primarySwatch: Colors.green, fontFamily: 'AnonymousPro'),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme
            .apply(fontFamily: 'AnonymousPro')
            .copyWith(
              bodyLarge: ThemeData.dark().textTheme.bodyLarge?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              bodyMedium: ThemeData.dark().textTheme.bodyMedium?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              bodySmall: ThemeData.dark().textTheme.bodySmall?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              headlineLarge: ThemeData.dark().textTheme.headlineLarge?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              headlineMedium: ThemeData.dark().textTheme.headlineMedium
                  ?.copyWith(
                    fontFamily: 'AnonymousPro',
                    fontWeight: FontWeight.bold,
                  ),
              headlineSmall: ThemeData.dark().textTheme.headlineSmall?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              titleMedium: ThemeData.dark().textTheme.titleMedium?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              titleSmall: ThemeData.dark().textTheme.titleSmall?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              labelLarge: ThemeData.dark().textTheme.labelLarge?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              labelMedium: ThemeData.dark().textTheme.labelMedium?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
              labelSmall: ThemeData.dark().textTheme.labelSmall?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AudioService _audioService;
  late final AppTrayManager _trayManager;
  late final WindowManagerWrapper _windowManagerWrapper;
  late final SettingsService _settingsService;

  bool _isPlaying = false;
  double _gainDb = -12.0;
  double _minMidiNote = 69.0; // A4 = 440 Hz
  double _maxMidiNote = 115.0; // Around 8000 Hz

  // Drag state for incremental sliders
  bool _isDragging = false;
  double _dragStartPosition = 0.0;
  double _dragStartValue = 0.0;
  Function(double)? _currentDragSetter;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _settingsService = SettingsService();

    if (PlatformUtils.isDesktop) {
      _windowManagerWrapper = WindowManagerWrapper(
        onWindowCloseCallback: _onWindowClose,
      );
      _trayManager = AppTrayManager(
        onShowWindow: _showWindow,
        onHideWindow: _hideWindow,
        onExitApp: _exitApp,
        isWindowVisible: () => _windowManagerWrapper.isWindowVisible,
      );

      Future.microtask(() async {
        try {
          await _windowManagerWrapper.init();
          await _trayManager.init();
          await _loadSettings();
          await _audioService.init();
          await _getInitialPlaybackState();
        } catch (e) {
          _showErrorSnackBar('Initialization failed: $e');
        }
      });
    } else {
      Future.microtask(() async {
        try {
          await _loadSettings();
          await _audioService.init();
          await _getInitialPlaybackState();
        } catch (e) {
          _showErrorSnackBar('Audio service initialization failed: $e');
        }
      });
    }
  }

  void _onWindowClose() {
    _hideWindow();
  }

  Future<void> _hideWindow() async {
    await _windowManagerWrapper.hideWindow();
    setState(() {}); // Trigger rebuild for UI consistency
  }

  Future<void> _showWindow() async {
    await _windowManagerWrapper.showWindow();
    setState(() {}); // Trigger rebuild for UI consistency
  }

  Future<void> _exitApp() async {
    _audioService.dispose();
    await _windowManagerWrapper.destroy();
  }

  @override
  void dispose() {
    _audioService.dispose();
    if (PlatformUtils.isDesktop) {
      _trayManager.dispose();
      _windowManagerWrapper.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.loadAllSettings();
    setState(() {
      _gainDb = settings['volume']!;
      _minMidiNote = AudioUtils.frequencyToMidiNote(settings['minFrequency']!);
      _maxMidiNote = AudioUtils.frequencyToMidiNote(settings['maxFrequency']!);
    });
  }

  Future<void> _getInitialPlaybackState() async {
    final isPlaying = await _audioService.isPlaying();
    setState(() {
      _isPlaying = isPlaying;
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _setGain(double gain) async {
    try {
      await _audioService.setGain(gain);
      await _settingsService.setVolume(gain);
    } catch (e) {
      _showErrorSnackBar('Failed to set gain: $e');
    }
  }

  Future<void> _setFrequencyRange(
    double minMidiNote,
    double maxMidiNote,
  ) async {
    try {
      setState(() {
        _minMidiNote = minMidiNote;
        _maxMidiNote = maxMidiNote;
      });
      final minFrequency = AudioUtils.midiNoteToFrequency(minMidiNote);
      final maxFrequency = AudioUtils.midiNoteToFrequency(maxMidiNote);
      await _settingsService.setMinFrequency(minFrequency);
      await _settingsService.setMaxFrequency(maxFrequency);
      await _audioService.setFrequencyRange(minMidiNote, maxMidiNote);
    } catch (e) {
      _showErrorSnackBar('Failed to set frequency range: $e');
    }
  }

  Future<void> _setMinMidiNote(double midiNote) async {
    await _setFrequencyRange(midiNote, _maxMidiNote);
  }

  Future<void> _setMaxMidiNote(double midiNote) async {
    await _setFrequencyRange(_minMidiNote, midiNote);
  }

  Widget _buildFrequencySlider(double value, Function(double) onValueChanged) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _isDragging = true;
        _dragStartPosition = details.localPosition.dx;
        _dragStartValue = value;
        _currentDragSetter = onValueChanged;
      },
      onHorizontalDragUpdate: (details) {
        if (_isDragging && _currentDragSetter != null) {
          double deltaX = details.localPosition.dx - _dragStartPosition;
          double sensitivity = 0.2; // Adjust for drag sensitivity
          double deltaValue = deltaX * sensitivity;
          double newValue = (_dragStartValue + deltaValue).clamp(28.0, 131.0);
          _currentDragSetter!(newValue);
        }
      },
      onHorizontalDragEnd: (details) {
        _isDragging = false;
        _currentDragSetter = null;
      },
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          disabledThumbColor:
              SliderTheme.of(context).thumbColor ??
              Theme.of(context).colorScheme.primary,
          disabledActiveTrackColor:
              SliderTheme.of(context).activeTrackColor ??
              Theme.of(context).colorScheme.primary,
          disabledInactiveTrackColor:
              SliderTheme.of(context).inactiveTrackColor ??
              Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
          disabledActiveTickMarkColor:
              SliderTheme.of(context).activeTickMarkColor ??
              Theme.of(context).colorScheme.primary,
          disabledInactiveTickMarkColor:
              SliderTheme.of(context).inactiveTickMarkColor ??
              Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
          disabledSecondaryActiveTrackColor:
              SliderTheme.of(context).secondaryActiveTrackColor ??
              Theme.of(context).colorScheme.primary.withOpacity(0.54),
        ),
        child: Slider(
          value: value,
          min: 28.0, // ~40 Hz
          max: 131.0, // ~16000 Hz
          label: AudioUtils.midiNoteToFrequency(value).round().toString(),
          onChanged: null, // Disable Slider's built-in interaction
        ),
      ),
    );
  }

  Future<void> _startTherapy() async {
    try {
      await _audioService.start();
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to start therapy: $e');
    }
  }

  Future<void> _stopTherapy() async {
    try {
      await _audioService.stop();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to stop therapy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: const Text('Sinewave Tinnitus Retraining')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: buildContent,
        ),
      ),
    );
  }

  List<Widget> get buildContent {
    return [
      Center(
        child: Text(
          'Min Frequency: ${AudioUtils.midiNoteToFrequency(_minMidiNote).toStringAsFixed(0)} Hz',
        ),
      ),
      _buildFrequencySlider(_minMidiNote, _setMinMidiNote),
      Center(
        child: Text(
          'Max Frequency: ${AudioUtils.midiNoteToFrequency(_maxMidiNote).toStringAsFixed(0)} Hz',
        ),
      ),
      _buildFrequencySlider(_maxMidiNote, _setMaxMidiNote),
      Center(child: Text('Gain: ${_gainDb.toStringAsFixed(1)} dB')),
      Slider(
        value: AudioUtils.dbToSlider(_gainDb),
        min: 0.0,
        max: 1.0,
        label: _gainDb.round().toString(),
        onChanged: (double value) {
          final db = AudioUtils.sliderToDb(value);
          setState(() {
            _gainDb = db;
          });
          _setGain(db);
        },
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _isPlaying ? _stopTherapy : _startTherapy,
        style: ElevatedButton.styleFrom(enableFeedback: false),
        child: Text(_isPlaying ? 'Stop Therapy' : 'Start Therapy'),
      ),
      const SizedBox(height: 20),
      Text(
        _isPlaying ? 'Therapy is playing in background' : 'Therapy is stopped',
        style: TextStyle(
          color: _isPlaying ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];
  }
}
