package com.voltdrive.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.voltdrive.app/assistant"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isOverlayGranted" -> {
                    result.success(OverlayManager.canDrawOverlays(context))
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "isAccessibilityEnabled" -> {
                    val isRunning = VoltAccessibilityService.isServiceRunning || isAccessibilitySettingsEnabled()
                    result.success(isRunning)
                }
                "requestAccessibilityPermission" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "showTestOffer" -> {
                    OverlayManager.showTestOffer(context)
                    result.success(true)
                }
                "hideOverlay" -> {
                    OverlayManager.hideOverlay()
                    result.success(true)
                }
                "updateSettings" -> {
                    val platformFee = (call.argument<Double>("platformFee") ?: 25.0) / 100.0
                    val energyCostPerKm = call.argument<Double>("energyCostPerKm") ?: 0.0409

                    val prefs = getSharedPreferences("VoltDrivePrefs", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putFloat("platformFeeRate", platformFee.toFloat())
                        .putFloat("energyCostPerKm", energyCostPerKm.toFloat())
                        .apply()

                    result.success(true)
                }
                else -> result.notImplemented()
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
