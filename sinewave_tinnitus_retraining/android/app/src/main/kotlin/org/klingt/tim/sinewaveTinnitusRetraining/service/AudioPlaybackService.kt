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

class AudioPlaybackService : Service() {
    private val binder = LocalBinder()
    private var audioManager: AudioManager? = null
    private var isPlaying = false
    private var isInitialized = false

    interface AudioServiceListener {
        fun onHeadphoneConnectionChanged(isConnected: Boolean)

        fun onPlaybackStateChanged(isPlaying: Boolean)
    }

    private var listener: AudioServiceListener? = null

    fun setListener(listener: AudioServiceListener?) {
        this.listener = listener
    }

    private val audioDeviceCallback =
        object : android.media.AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out android.media.AudioDeviceInfo>?) {
                super.onAudioDevicesAdded(addedDevices)
                val connected = isHeadphoneConnected()
                listener?.onHeadphoneConnectionChanged(connected)
                if (connected && !isPlaying) {
                    startAudioPlayback()
                }
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<out android.media.AudioDeviceInfo>?) {
                super.onAudioDevicesRemoved(removedDevices)
                val connected = isHeadphoneConnected()
                listener?.onHeadphoneConnectionChanged(connected)
                if (!connected && isPlaying) {
                    stopAudioPlayback()
                }
            }
        }

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
        audioManager?.registerAudioDeviceCallback(audioDeviceCallback, null)
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
        // Ensure the service stays running
        startForeground(NOTIFICATION_ID, createNotification())
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

    fun isHeadphoneConnected(): Boolean {
        // AudioManager.GET_DEVICES_OUTPUT is 2
        val devices = audioManager?.getDevices(2) ?: return false
        for (device in devices) {
            val type = device.type
            if (type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                type == android.media.AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET
            ) {
                return true
            }
        }
        return false
    }

    private fun startAudioPlayback() {
        if (!isInitialized) {
            Log.e(TAG, "Audio player not initialized")
            return
        }

        if (!isHeadphoneConnected()) {
            Log.d(TAG, "No headphones connected, skipping playback start")
            // Update notification to indicate waiting for headphones
            startForeground(NOTIFICATION_ID, createNotification())
            return
        }

        // We do NOT request audio focus to allow mixing with other apps
        try {
            val status = start_audio_player()
            if (status == 1) {
                isPlaying = true
                listener?.onPlaybackStateChanged(true)
                startForeground(NOTIFICATION_ID, createNotification())
                Log.d(TAG, "Audio playback started")
            } else {
                Log.e(TAG, "Failed to start audio playback")
            }
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Native audio functions not available, service running in background mode only")
            isPlaying = true
            listener?.onPlaybackStateChanged(true)
            startForeground(NOTIFICATION_ID, createNotification())
        } catch (e: Exception) {
            Log.e(TAG, "Error starting audio playback", e)
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
        listener?.onPlaybackStateChanged(false)
        // Update notification to show paused state, but keep service running
        startForeground(NOTIFICATION_ID, createNotification())
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
        listener?.onPlaybackStateChanged(false)
        startForeground(NOTIFICATION_ID, createNotification())
    }

    private fun resumeAudioPlayback() {
        if (isInitialized && !isPlaying) {
            if (!isHeadphoneConnected()) {
                Log.d(TAG, "Cannot resume: No headphones connected")
                return
            }
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
        listener?.onPlaybackStateChanged(true)
        startForeground(NOTIFICATION_ID, createNotification())
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

    private fun createNotification(): Notification {
        val text =
            if (isPlaying) {
                "Playing therapy sound"
            } else if (!isHeadphoneConnected()) {
                "Waiting for headphones..."
            } else {
                "Paused"
            }

        return NotificationCompat
            .Builder(this, CHANNEL_ID)
            .setContentTitle("Sinewave Tinnitus Retraining")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true) // Always ongoing to keep service alive
            .build()
    }

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
        audioManager?.unregisterAudioDeviceCallback(audioDeviceCallback)
        listener = null
    }
}
