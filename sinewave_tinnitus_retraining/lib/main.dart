import 'package:flutter/material.dart';

import 'audio_service.dart';
import 'audio_utils.dart';
import 'platform_utils.dart';
import 'settings_service.dart';
import 'settings_controller.dart';
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
  late final SettingsController _settingsController;

  bool _isPlaying = false;
  bool _isHeadphoneConnected = false;

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
    _settingsController = SettingsController(_settingsService, _audioService);

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
          await _settingsController.init();
          await _audioService.init();
          await _getInitialPlaybackState();
          _setupAudioServiceListeners();
        } catch (e) {
          _showErrorSnackBar('Initialization failed: $e');
        }
      });
    } else {
      Future.microtask(() async {
        try {
          await _settingsController.init();
          await _audioService.init();
          await _getInitialPlaybackState();
          _setupAudioServiceListeners();
        } catch (e) {
          _showErrorSnackBar('Audio service initialization failed: $e');
        }
      });
    }
  }

  void _setupAudioServiceListeners() {
    _audioService.onHeadphoneConnectionChanged.listen((isConnected) {
      setState(() {
        _isHeadphoneConnected = isConnected;
      });
    });

    _audioService.onPlaybackStateChanged.listen((isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    });
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
    _settingsController.dispose();
    if (PlatformUtils.isDesktop) {
      _trayManager.dispose();
      _windowManagerWrapper.dispose();
    }
    super.dispose();
  }

  Future<void> _getInitialPlaybackState() async {
    final isPlaying = await _audioService.isPlaying();
    final isHeadphoneConnected = await _audioService.isHeadphoneConnected();
    setState(() {
      _isPlaying = isPlaying;
      _isHeadphoneConnected = isHeadphoneConnected;
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
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
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          disabledActiveTickMarkColor:
              SliderTheme.of(context).activeTickMarkColor ??
              Theme.of(context).colorScheme.primary,
          disabledInactiveTickMarkColor:
              SliderTheme.of(context).inactiveTickMarkColor ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          disabledSecondaryActiveTrackColor:
              SliderTheme.of(context).secondaryActiveTrackColor ??
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.54),
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

  Widget _buildChannelControls({
    required String title,
    required ChannelSettings settings,
    required Function(ChannelSettings) onUpdate,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            'Min Freq: ${AudioUtils.midiNoteToFrequency(settings.minFrequency).toStringAsFixed(0)} Hz',
          ),
          _buildFrequencySlider(settings.minFrequency, (val) {
            onUpdate(settings.copyWith(minFrequency: val));
          }),
          Text(
            'Max Freq: ${AudioUtils.midiNoteToFrequency(settings.maxFrequency).toStringAsFixed(0)} Hz',
          ),
          _buildFrequencySlider(settings.maxFrequency, (val) {
            onUpdate(settings.copyWith(maxFrequency: val));
          }),
          Text('Gain: ${settings.volume.toStringAsFixed(1)} dB'),
          Slider(
            value: AudioUtils.dbToSlider(settings.volume),
            min: 0.0,
            max: 1.0,
            label: settings.volume.round().toString(),
            onChanged: (double value) {
              final db = AudioUtils.sliderToDb(value);
              onUpdate(settings.copyWith(volume: db));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startTherapy() async {
    try {
      await _audioService.start();
      // State update will come from listener
    } catch (e) {
      _showErrorSnackBar('Failed to start therapy: $e');
    }
  }

  Future<void> _stopTherapy() async {
    try {
      await _audioService.stop();
      // State update will come from listener
    } catch (e) {
      _showErrorSnackBar('Failed to stop therapy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Sinewave Tinnitus Retraining')),
      ),
      body: Center(
        child: ValueListenableBuilder<AppSettings>(
          valueListenable: _settingsController.settings,
          builder: (context, settings, child) {
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildChannelControls(
                        title: 'Left Channel',
                        settings: settings.leftChannel,
                        onUpdate: _settingsController.updateLeftChannel,
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      _buildChannelControls(
                        title: 'Right Channel',
                        settings: settings.rightChannel,
                        onUpdate: _settingsController.updateRightChannel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isHeadphoneConnected
                            ? Icons.headset
                            : Icons.headset_off,
                        color: _isHeadphoneConnected
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isHeadphoneConnected
                            ? 'Headphones Connected'
                            : 'No Headphones',
                        style: TextStyle(
                          color: _isHeadphoneConnected
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isPlaying ? _stopTherapy : _startTherapy,
                    style: ElevatedButton.styleFrom(enableFeedback: false),
                    child: Text(_isPlaying ? 'Stop Therapy' : 'Start Therapy'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isPlaying
                        ? 'Therapy is playing'
                        : (!_isHeadphoneConnected
                              ? 'Waiting for headphones...'
                              : 'Therapy is stopped'),
                    style: TextStyle(
                      color: _isPlaying
                          ? Colors.green
                          : (!_isHeadphoneConnected
                                ? Colors.orange
                                : Colors.red),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
