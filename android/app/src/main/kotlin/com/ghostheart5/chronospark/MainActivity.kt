package com.ghostheart5.chronospark

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val locationChannelName = "chronospark/location"
    private val ttsChannelName = "chronospark/tts"
    private val locationRequestCode = 41005
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var locationPermissionRequested = false
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var pendingTtsInitResult: MethodChannel.Result? = null
    private val pendingSpeakResults = mutableMapOf<String, MethodChannel.Result>()
    private var ttsVolume = 1.0f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isLocationServiceEnabled" -> result.success(isLocationServiceEnabled())
                    "checkPermission" -> result.success(locationPermissionState())
                    "requestPermission" -> requestLocationPermission(result)
                    "getLastKnownPosition" -> result.success(lastKnownLocation()?.toMap())
                    "getCurrentPosition" -> currentLocation(result)
                    "openAppSettings" -> result.success(openIntent(appSettingsIntent()))
                    "openLocationSettings" -> result.success(openIntent(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)))
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ttsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> initializeTts(result)
                    "speak" -> speakText(call.argument<String>("text").orEmpty(), result)
                    "stop" -> stopTts(result)
                    "pause" -> stopTts(result)
                    "setLanguage" -> setTtsLanguage(call.arguments as? String, result)
                    "setVolume" -> setTtsVolume(call.arguments as? Number, result)
                    "setRate" -> setTtsRate(call.arguments as? Number, result)
                    "setPitch" -> setTtsPitch(call.arguments as? Number, result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        completePendingSpeaks()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        ttsReady = false
        pendingTtsInitResult = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != locationRequestCode) {
            return
        }
        pendingPermissionResult?.success(locationPermissionState())
        pendingPermissionResult = null
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (hasLocationPermission()) {
            result.success("whileInUse")
            return
        }
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_REQUEST_IN_PROGRESS", "A location permission request is already active.", null)
            return
        }
        pendingPermissionResult = result
        locationPermissionRequested = true
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            locationRequestCode,
        )
    }

    private fun currentLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error("LOCATION_PERMISSION_DENIED", "Location permission is not granted.", null)
            return
        }
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val provider = bestEnabledProvider(manager)
        if (provider == null) {
            result.error("LOCATION_SERVICE_DISABLED", "Location services are disabled.", null)
            return
        }
        val timeout = Handler(Looper.getMainLooper())
        var completed = false
        val listener =
            object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    if (completed) return
                    completed = true
                    timeout.removeCallbacksAndMessages(null)
                    manager.removeUpdates(this)
                    result.success(location.toMap())
                }
            }
        timeout.postDelayed({
            if (completed) return@postDelayed
            completed = true
            manager.removeUpdates(listener)
            val fallback = lastKnownLocation()
            if (fallback != null) {
                result.success(fallback.toMap())
            } else {
                result.error("LOCATION_TIMEOUT", "No location fix was available.", null)
            }
        }, 10_000)
        try {
            manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        } catch (error: SecurityException) {
            completed = true
            timeout.removeCallbacksAndMessages(null)
            result.error("LOCATION_PERMISSION_DENIED", error.message, null)
        } catch (error: IllegalArgumentException) {
            completed = true
            timeout.removeCallbacksAndMessages(null)
            result.error("LOCATION_UNAVAILABLE", error.message, null)
        }
    }

    private fun lastKnownLocation(): Location? {
        if (!hasLocationPermission()) {
            return null
        }
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return manager.getProviders(true)
            .mapNotNull { provider ->
                try {
                    manager.getLastKnownLocation(provider)
                } catch (_: SecurityException) {
                    null
                }
            }
            .maxByOrNull { it.time }
    }

    private fun isLocationServiceEnabled(): Boolean {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun bestEnabledProvider(manager: LocationManager): String? {
        return when {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> null
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun locationPermissionState(): String {
        if (hasLocationPermission()) {
            return "whileInUse"
        }
        val fineRationale = ActivityCompat.shouldShowRequestPermissionRationale(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )
        val coarseRationale = ActivityCompat.shouldShowRequestPermissionRationale(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
        return if (locationPermissionRequested && !fineRationale && !coarseRationale) {
            "deniedForever"
        } else {
            "denied"
        }
    }

    private fun appSettingsIntent(): Intent {
        return Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
    }

    private fun openIntent(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun initializeTts(result: MethodChannel.Result) {
        if (ttsReady && textToSpeech != null) {
            result.success(null)
            return
        }
        if (pendingTtsInitResult != null) {
            result.error("TTS_INIT_IN_PROGRESS", "Text to speech initialization is already active.", null)
            return
        }
        pendingTtsInitResult = result
        textToSpeech = TextToSpeech(this) { status ->
            runOnUiThread {
                val initResult = pendingTtsInitResult
                pendingTtsInitResult = null
                if (status == TextToSpeech.SUCCESS) {
                    ttsReady = true
                    textToSpeech?.language = Locale.US
                    textToSpeech?.setOnUtteranceProgressListener(ttsProgressListener())
                    initResult?.success(null)
                } else {
                    ttsReady = false
                    initResult?.error("TTS_UNAVAILABLE", "Text to speech engine is unavailable.", null)
                }
            }
        }
    }

    private fun speakText(text: String, result: MethodChannel.Result) {
        if (!ttsReady || textToSpeech == null) {
            result.error("TTS_NOT_READY", "Text to speech is not initialized.", null)
            return
        }
        if (text.isBlank()) {
            result.success(null)
            return
        }
        val utteranceId = UUID.randomUUID().toString()
        pendingSpeakResults[utteranceId] = result
        val params = Bundle().apply {
            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, ttsVolume)
        }
        val status = textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
        if (status == TextToSpeech.ERROR) {
            pendingSpeakResults.remove(utteranceId)
            result.error("TTS_SPEAK_FAILED", "Text to speech failed to speak.", null)
        }
    }

    private fun stopTts(result: MethodChannel.Result) {
        textToSpeech?.stop()
        completePendingSpeaks()
        result.success(null)
    }

    private fun setTtsLanguage(language: String?, result: MethodChannel.Result) {
        if (!ttsReady || textToSpeech == null) {
            result.error("TTS_NOT_READY", "Text to speech is not initialized.", null)
            return
        }
        val locale = language?.takeIf { it.isNotBlank() }?.let { Locale.forLanguageTag(it) } ?: Locale.US
        val status = textToSpeech?.setLanguage(locale)
        if (status == TextToSpeech.LANG_MISSING_DATA || status == TextToSpeech.LANG_NOT_SUPPORTED) {
            result.error("TTS_LANGUAGE_UNAVAILABLE", "Text to speech language is unavailable.", null)
        } else {
            result.success(null)
        }
    }

    private fun setTtsVolume(volume: Number?, result: MethodChannel.Result) {
        ttsVolume = volume?.toFloat()?.coerceIn(0.0f, 1.0f) ?: 1.0f
        result.success(null)
    }

    private fun setTtsRate(rate: Number?, result: MethodChannel.Result) {
        if (!ttsReady || textToSpeech == null) {
            result.error("TTS_NOT_READY", "Text to speech is not initialized.", null)
            return
        }
        textToSpeech?.setSpeechRate(rate?.toFloat()?.coerceIn(0.0f, 1.0f) ?: 0.5f)
        result.success(null)
    }

    private fun setTtsPitch(pitch: Number?, result: MethodChannel.Result) {
        if (!ttsReady || textToSpeech == null) {
            result.error("TTS_NOT_READY", "Text to speech is not initialized.", null)
            return
        }
        textToSpeech?.setPitch(pitch?.toFloat()?.coerceIn(0.5f, 2.0f) ?: 1.0f)
        result.success(null)
    }

    private fun ttsProgressListener(): UtteranceProgressListener {
        return object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                finishSpeak(utteranceId, null)
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                finishSpeak(utteranceId, null)
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                finishSpeak(utteranceId, null)
            }
        }
    }

    private fun finishSpeak(utteranceId: String?, errorMessage: String?) {
        if (utteranceId == null) return
        runOnUiThread {
            val result = pendingSpeakResults.remove(utteranceId) ?: return@runOnUiThread
            if (errorMessage == null) {
                result.success(null)
            } else {
                result.error("TTS_SPEAK_FAILED", errorMessage, null)
            }
        }
    }

    private fun completePendingSpeaks() {
        val results = pendingSpeakResults.values.toList()
        pendingSpeakResults.clear()
        results.forEach { it.success(null) }
    }

    private fun Location.toMap(): Map<String, Any> {
        return mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to accuracy.toDouble(),
            "timestamp" to time,
        )
    }
}
