package org.klingt.tim.sinewaveTinnitusRetraining.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import org.klingt.tim.sinewaveTinnitusRetraining.R

class AudioPlaybackService :
    Service(),
    AudioManager.OnAudioFocusChangeListener {
    private val binder = LocalBinder()
    private var audioManager: AudioManager? = null
    private var isPlaying = false
    private var isInitialized = false

    companion object {
        const val NOTIFICATION_ID = 1
        const val CHANNEL_ID = "AudioPlaybackChannel"
        const val ACTION_START = "org.klingt.tim.sinewaveTinnitusRetraining.START"
        const val ACTION_STOP = "org.klingt.tim.sinewaveTinnitusRetraining.STOP"
        const val ACTION_PAUSE = "org.klingt.tim.sinewaveTinnitusRetraining.PAUSE"
        const val ACTION_RESUME = "org.klingt.tim.sinewaveTinnitusRetraining.RESUME"
        const val ACTION_SET_GAIN = "org.klingt.tim.sinewaveTinnitusRetraining.SET_GAIN"
        const val ACTION_SET_FREQUENCY_RANGE = "org.klingt.tim.sinewaveTinnitusRetraining.SET_FREQUENCY_RANGE"
        private const val TAG = "AudioPlaybackService"
    }

    inner class LocalBinder : Binder() {
        fun getService(): AudioPlaybackService = this@AudioPlaybackService
    }

    fun isPlaying(): Boolean = isPlaying

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        initializeAudioPlayer()
    }

    override fun onBind(intent: Intent): IBinder = binder

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        when (intent?.action) {
            ACTION_START -> {
                startAudioPlayback()
            }
            ACTION_STOP -> {
                stopAudioPlayback()
            }
            ACTION_PAUSE -> {
                pauseAudioPlayback()
            }
            ACTION_RESUME -> {
                resumeAudioPlayback()
            }
            ACTION_SET_GAIN -> {
                val gain = intent.getFloatExtra("gain", 0.0f)
                setGainValue(gain)
            }
            ACTION_SET_FREQUENCY_RANGE -> {
                val minMidiNote = intent.getFloatExtra("minMidiNote", 69.0f)
                val maxMidiNote = intent.getFloatExtra("maxMidiNote", 115.0f)
                setFrequencyRangeValue(minMidiNote, maxMidiNote)
            }
        }
        return START_STICKY
    }

    private fun initializeAudioPlayer() {
        try {
            // Load the native library
            System.loadLibrary("sinewave_tinnitus_retraining_audio_core")
            Log.d(TAG, "Native library loaded successfully")

            // Try to create the actual audio player using global static
            val result = create_audio_player()
            if (result == 1) {
                isInitialized = true
                Log.d(TAG, "Audio player initialized successfully")
            } else {
                Log.e(TAG, "Failed to create audio player")
            }
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Native function not available, using dummy implementation")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing audio player", e)
        }
    }

    // Declare the JNI functions (no parameters needed since we use global static)
    @Suppress("ktlint:standard:function-naming")
    private external fun create_audio_player(): Int

    @Suppress("ktlint:standard:function-naming")
    private external fun start_audio_player(): Int

    @Suppress("ktlint:standard:function-naming")
    private external fun stop_audio_player(): Int

    @Suppress("ktlint:standard:function-naming")
    private external fun destroy_audio_player(): Int

    @Suppress("ktlint:standard:function-naming")
    private external fun setGain(gainDb: Float)

    @Suppress("ktlint:standard:function-naming")
    private external fun setFrequencyRange(
        minMidiNote: Float,
        maxMidiNote: Float,
    )

    private fun setGainValue(gain: Float) {
        try {
            setGain(gain)
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Native setGain function not available")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting gain", e)
        }
    }

    private fun setFrequencyRangeValue(
        minMidiNote: Float,
        maxMidiNote: Float,
    ) {
        try {
            setFrequencyRange(minMidiNote, maxMidiNote)
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Native setFrequencyRange function not available")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting frequency range", e)
        }
    }

    private fun startAudioPlayback() {
        if (!isInitialized) {
            Log.e(TAG, "Audio player not initialized")
            return
        }

        // Request audio focus
        val result =
            audioManager?.requestAudioFocus(
                this,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )

        if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            try {
                val status = start_audio_player()
                if (status == 1) {
                    isPlaying = true
                    startForeground(NOTIFICATION_ID, createNotification())
                    Log.d(TAG, "Audio playback started")
                } else {
                    Log.e(TAG, "Failed to start audio playback")
                }
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "Native audio functions not available, service running in background mode only")
                isPlaying = true
                startForeground(NOTIFICATION_ID, createNotification())
            } catch (e: Exception) {
                Log.e(TAG, "Error starting audio playback", e)
            }
        } else {
            Log.e(TAG, "Failed to get audio focus")
        }
    }

    private fun stopAudioPlayback() {
        if (isInitialized) {
            try {
                val status = stop_audio_player()
                if (status == 1) {
                    Log.d(TAG, "Audio playback stopped")
                }
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "Native audio functions not available")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping audio playback", e)
            }
        }

        isPlaying = false

        // Abandon audio focus
        audioManager?.abandonAudioFocus(this)

        stopForeground(true)
        stopSelf()
    }

    private fun pauseAudioPlayback() {
        if (isInitialized && isPlaying) {
            try {
                val status = stop_audio_player()
                if (status == 1) {
                    Log.d(TAG, "Audio playback paused")
                }
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "Native audio functions not available")
            } catch (e: Exception) {
                Log.e(TAG, "Error pausing audio playback", e)
            }
        }
        isPlaying = false
    }

    private fun resumeAudioPlayback() {
        if (isInitialized && !isPlaying) {
            try {
                val status = start_audio_player()
                if (status == 1) {
                    Log.d(TAG, "Audio playback resumed")
                }
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "Native audio functions not available")
            } catch (e: Exception) {
                Log.e(TAG, "Error resuming audio playback", e)
            }
        }
        isPlaying = true
    }

    override fun onAudioFocusChange(focusChange: Int) {
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                // Permanent loss of audio focus
                // stopAudioPlayback()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // Temporary loss of audio focus
                // pauseAudioPlayback()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // Lower the volume
                // For now, we'll pause since our audio needs to be at full volume
                // pauseAudioPlayback()
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                // Regained audio focus
                if (!isPlaying) {
                    resumeAudioPlayback()
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                NotificationChannel(CHANNEL_ID, "Audio Playback", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Sinewave Tinnitus Retraining audio playback" }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification =
        NotificationCompat
            .Builder(this, CHANNEL_ID)
            .setContentTitle("Sinewave Tinnitus Retraining")
            .setContentText(if (isPlaying) "Playing therapy sound" else "Paused")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(isPlaying)
            .build()

    override fun onDestroy() {
        super.onDestroy()
        if (isInitialized) {
            try {
                val status = destroy_audio_player()
                if (status == 1) {
                    Log.d(TAG, "Audio player destroyed")
                }
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "Native audio functions not available")
            } catch (e: Exception) {
                Log.e(TAG, "Error destroying audio player", e)
            }
        }
        audioManager?.abandonAudioFocus(this)
    }
}
