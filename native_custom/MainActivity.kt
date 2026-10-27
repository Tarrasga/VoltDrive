package com.voltdrive.app

import android.annotation.SuppressLint
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.voltdrive.app/assistant"
    private var pendingLocationResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 3001)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isOverlayGranted" -> {
                    result.success(OverlayManager.canDrawOverlays(applicationContext))
                }
                "requestOverlayPermission" -> {
                    var launched = false
                    // 1. Try with Uri.parse("package:$packageName")
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        launched = true
                    } catch (e: Exception) {}

                    // 2. Try generic ACTION_MANAGE_OVERLAY_PERMISSION (Universal on all Android)
                    if (!launched) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            launched = true
                        } catch (e: Exception) {}
                    }

                    // 3. Fallback: App Details Settings
                    if (!launched) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            launched = true
                        } catch (e: Exception) {}
                    }
                    result.success(launched)
                }
                "isAccessibilityEnabled" -> {
                    val isRunning = VoltAccessibilityService.isServiceRunning || isAccessibilitySettingsEnabled()
                    result.success(isRunning)
                }
                "isScreenReaderPaused" -> {
                    val prefs = getSharedPreferences("voltdrive_prefs", Context.MODE_PRIVATE)
                    val paused = prefs.getBoolean("screen_reader_paused", false)
                    VoltAccessibilityService.isReadingPaused = paused
                    result.success(paused)
                }
                "setScreenReaderPaused" -> {
                    val paused = call.argument<Boolean>("paused") ?: true
                    VoltAccessibilityService.isReadingPaused = paused
                    val prefs = getSharedPreferences("voltdrive_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("screen_reader_paused", paused).apply()
                    if (paused) {
                        OverlayManager.hideOverlay()
                    }
                    result.success(true)
                }
                "stopAccessibilityService" -> {
                    VoltAccessibilityService.isReadingPaused = true
                    val prefs = getSharedPreferences("voltdrive_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("screen_reader_paused", true).apply()
                    OverlayManager.hideOverlay()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        VoltAccessibilityService.instance?.disableSelf()
                    }
                    result.success(true)
                }
                "requestAccessibilityPermission" -> {
                    var launched = false
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        launched = true
                    } catch (e: Exception) {}

                    if (!launched) {
                        try {
                            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            launched = true
                        } catch (e: Exception) {}
                    }
                    result.success(launched)
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FAILED", e.message, null)
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 3001)
                    }
                    result.success(true)
                }
                "requestLocationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                            2001
                        )
                    }
                    result.success(true)
                }
                "showTestOffer" -> {
                    val shown = OverlayManager.showTestOffer(applicationContext)
                    result.success(shown)
                }
                "hideOverlay" -> {
                    OverlayManager.hideOverlay()
                    result.success(true)
                }
                "updateSettings" -> {
                    val platformFee = (call.argument<Double>("platformFee") ?: 25.0) / 100.0
                    val energyCostPerKm = call.argument<Double>("energyCostPerKm") ?: 0.0409
                    val overlayTimeoutSeconds = call.argument<Int>("overlayTimeoutSeconds") ?: 12

                    val prefs = getSharedPreferences("VoltDrivePrefs", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putFloat("platformFeeRate", platformFee.toFloat())
                        .putFloat("energyCostPerKm", energyCostPerKm.toFloat())
                        .putInt("overlayTimeoutSeconds", overlayTimeoutSeconds)
                        .apply()

                    result.success(true)
                }
                "getLocation" -> {
                    fetchCurrentLocation(result)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isNotEmpty()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL is empty", null)
                    }
                }
                "sendEmergencySms" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    try {
                        val uri = if (phone.isNotEmpty()) Uri.parse("smsto:$phone") else Uri.parse("smsto:")
                        val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                            putExtra("sms_body", message)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.message, null)
                    }
                }
                "shareWhatsApp" -> {
                    val rawPhone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    try {
                        val encoded = Uri.encode(message)
                        val cleanDigits = rawPhone.replace(Regex("[^0-9]"), "")
                        val finalPhone = if (cleanDigits.length == 9 && (cleanDigits.startsWith("9") || cleanDigits.startsWith("2"))) {
                            "351$cleanDigits"
                        } else {
                            cleanDigits
                        }
                        val url = if (finalPhone.isNotEmpty()) {
                            "https://api.whatsapp.com/send?phone=$finalPhone&text=$encoded"
                        } else {
                            "https://api.whatsapp.com/send?text=$encoded"
                        }
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WHATSAPP_FAILED", e.message, null)
                    }
                }
                "getCacheDir" -> {
                    try {
                        result.success(applicationContext.cacheDir.absolutePath)
                    } catch (e: Exception) {
                        result.error("CACHE_DIR_FAILED", e.message, null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "requestInstallPackagesPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val reqIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(reqIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("REQ_PERMISSION_FAILED", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val file = java.io.File(filePath)
                    if (file.exists()) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                if (!packageManager.canRequestPackageInstalls()) {
                                    val reqIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                        data = Uri.parse("package:$packageName")
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(reqIntent)
                                }
                            }

                            val uri = androidx.core.content.FileProvider.getUriForFile(
                                this@MainActivity,
                                "$packageName.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("FILE_NOT_FOUND", "Ficheiro APK não encontrado: $filePath", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun fetchCurrentLocation(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!fine && !coarse) {
                pendingLocationResult = result
                requestPermissions(
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                    2001
                )
                return
            }
        }

        retrieveLocationFromManager(result)
    }

    @SuppressLint("MissingPermission")
    private fun retrieveLocationFromManager(result: MethodChannel.Result) {
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) {
            result.error("NO_LOCATION_MANAGER", "LocationManager unavailable", null)
            return
        }

        try {
            var bestLoc: Location? = null
            val providers = lm.getProviders(true)
            for (provider in providers) {
                val l = lm.getLastKnownLocation(provider) ?: continue
                if (bestLoc == null || l.accuracy < bestLoc.accuracy) {
                    bestLoc = l
                }
            }

            if (bestLoc != null) {
                val resMap = mapOf(
                    "lat" to bestLoc.latitude,
                    "lng" to bestLoc.longitude,
                    "accuracy" to bestLoc.accuracy.toDouble(),
                    "speed" to bestLoc.speed.toDouble()
                )
                result.success(resMap)
                return
            }

            // Fallback: one-shot listener
            val handler = Handler(Looper.getMainLooper())
            var answered = false

            val listener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    if (!answered) {
                        answered = true
                        lm.removeUpdates(this)
                        val resMap = mapOf(
                            "lat" to loc.latitude,
                            "lng" to loc.longitude,
                            "accuracy" to loc.accuracy.toDouble(),
                            "speed" to loc.speed.toDouble()
                        )
                        result.success(resMap)
                    }
                }
                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            val providerToUse = if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                LocationManager.GPS_PROVIDER
            } else {
                LocationManager.NETWORK_PROVIDER
            }

            lm.requestLocationUpdates(providerToUse, 500L, 0f, listener, Looper.getMainLooper())

            // Timeout after 4 seconds if no fix
            handler.postDelayed({
                if (!answered) {
                    answered = true
                    lm.removeUpdates(listener)
                    // Return default Lisbon/Portugal coordinates as fallback if GPS indoors
                    val fallbackMap = mapOf(
                        "lat" to 38.6500,
                        "lng" to -9.1500,
                        "accuracy" to 100.0,
                        "speed" to 0.0
                    )
                    result.success(fallbackMap)
                }
            }, 4000)

        } catch (e: Exception) {
            result.error("LOCATION_ERROR", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2001) {
            val pending = pendingLocationResult
            pendingLocationResult = null
            if (pending != null) {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                if (granted) {
                    retrieveLocationFromManager(pending)
                } else {
                    pending.error("PERMISSION_DENIED", "GPS permission denied", null)
                }
            }
        }
    }

    private fun isAccessibilitySettingsEnabled(): Boolean {
        try {
            val expectedServiceName = "$packageName/${VoltAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return enabledServices.contains(expectedServiceName) || enabledServices.contains(VoltAccessibilityService::class.java.simpleName)
        } catch (e: Exception) {
            return false
        }
    }
}
