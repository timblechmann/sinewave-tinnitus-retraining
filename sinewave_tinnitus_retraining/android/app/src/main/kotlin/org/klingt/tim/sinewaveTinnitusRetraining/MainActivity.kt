package org.klingt.tim.sinewaveTinnitusRetraining

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.klingt.tim.sinewaveTinnitusRetraining.service.AudioPlaybackService

class MainActivity :
    FlutterActivity(),
    AudioPlaybackService.AudioServiceListener {
    private val channel = "org.klingt.tim.sinewaveTinnitusRetraining/audio_service"
    private val tag = "MainActivity"
    private var audioService: AudioPlaybackService? = null
    private var isBound = false
    private var methodChannel: MethodChannel? = null

    private val connection =
        object : ServiceConnection {
            override fun onServiceConnected(
                className: ComponentName,
                service: IBinder,
            ) {
                val binder = service as AudioPlaybackService.LocalBinder
                audioService = binder.getService()
                audioService?.setListener(this@MainActivity)
                isBound = true
                Log.d(tag, "AudioPlaybackService connected")
            }

            override fun onServiceDisconnected(arg0: ComponentName) {
                isBound = false
                audioService?.setListener(null)
                audioService = null
                Log.d(tag, "AudioPlaybackService disconnected")
            }
        }

    override fun onHeadphoneConnectionChanged(isConnected: Boolean) {
        runOnUiThread {
            methodChannel?.invokeMethod("onHeadphoneConnectionChanged", isConnected)
        }
    }

    override fun onPlaybackStateChanged(isPlaying: Boolean) {
        runOnUiThread {
            methodChannel?.invokeMethod("onPlaybackStateChanged", isPlaying)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Intent(this, AudioPlaybackService::class.java).also { intent ->
            bindService(intent, connection, Context.BIND_AUTO_CREATE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        methodChannel?.setMethodCallHandler {
            call,
            result,
            ->
            when (call.method) {
                "startAudioService" -> {
                    val intent = Intent(this, AudioPlaybackService::class.java)
                    intent.action = AudioPlaybackService.ACTION_START
                    startService(intent)
                    result.success(null)
                    Log.d(tag, "Started audio service")
                }

                "stopAudioService" -> {
                    val intent = Intent(this, AudioPlaybackService::class.java)
                    intent.action = AudioPlaybackService.ACTION_STOP
                    startService(intent)
                    result.success(null)
                    Log.d(tag, "Stopped audio service")
                }

                "pauseAudioService" -> {
                    val intent = Intent(this, AudioPlaybackService::class.java)
                    intent.action = AudioPlaybackService.ACTION_PAUSE
                    startService(intent)
                    result.success(null)
                    Log.d(tag, "Paused audio service")
                }

                "resumeAudioService" -> {
                    val intent = Intent(this, AudioPlaybackService::class.java)
                    intent.action = AudioPlaybackService.ACTION_RESUME
                    startService(intent)
                    result.success(null)
                    Log.d(tag, "Resumed audio service")
                }

                "setGain" -> {
                    val gain = call.argument<Double>("gain")?.toFloat() ?: 0.0f
                    val intent = Intent(this, AudioPlaybackService::class.java)
                    intent.action = AudioPlaybackService.ACTION_SET_GAIN
                    intent.putExtra("gain", gain)
                    startService(intent)
                    result.success(null)
                }

                "setFrequencyRange" -> {
                    val minMidiNote = call.argument<Double>("minMidiNote")?.toFloat() ?: 69.0f
                    val maxMidiNote = call.argument<Double>("maxMidiNote")?.toFloat() ?: 115.0f
                    val intent = Intent(this, AudioPlaybackService::class.java)
                    intent.action = AudioPlaybackService.ACTION_SET_FREQUENCY_RANGE
                    intent.putExtra("minMidiNote", minMidiNote)
                    intent.putExtra("maxMidiNote", maxMidiNote)
                    startService(intent)
                    result.success(null)
                }

                "getPlaybackState" -> {
                    if (isBound) {
                        result.success(audioService?.isPlaying())
                    } else {
                        result.success(false)
                    }
                }

                "getHeadphoneState" -> {
                    if (isBound) {
                        result.success(audioService?.isHeadphoneConnected())
                    } else {
                        result.success(false)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isBound) {
            audioService?.setListener(null)
            unbindService(connection)
            isBound = false
        }
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
}
