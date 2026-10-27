package com.voltdrive.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.regex.Pattern
import kotlin.math.abs

class VoltAccessibilityService : AccessibilityService() {

    companion object {
        var isServiceRunning = false
        var lastOfferTimestamp = 0L
        var lastGrossFare = 0.0
        var lastDistanceKm = 0.0
    }

    private val pricePattern = Pattern.compile("(?:(?:€|EUR)\\s*([0-9]+[.,][0-9]{2})|([0-9]+[.,][0-9]{2})\\s*(?:€|EUR))", Pattern.CASE_INSENSITIVE)
    private val distKmPattern = Pattern.compile("([0-9]+[.,]?[0-9]*)\\s*km\\b", Pattern.CASE_INSENSITIVE)
    private val distMeterPattern = Pattern.compile("\\b([0-9]{2,4})\\s*m\\b", Pattern.CASE_INSENSITIVE)

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        android.util.Log.i("VoltDrive", "VoltAccessibilityService connected and active!")
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        OverlayManager.hideOverlay()
        android.util.Log.i("VoltDrive", "VoltAccessibilityService destroyed.")
    }

    override fun onInterrupt() {
        isServiceRunning = false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        val isUber = pkg.contains("ubercab.driver")
        val isBolt = pkg.contains("mtakso.driver") || pkg.contains("bolt.driver")

        if (!isUber && !isBolt) return

        val rootNode = rootInActiveWindow ?: event.source ?: return

        val textList = mutableListOf<String>()
        extractNodeTexts(rootNode, textList)

        if (textList.isNotEmpty()) {
            parseAndProcessOffer(
                platform = if (isBolt) "BOLT" else "UBER",
                texts = textList
            )
        }
    }

    private fun extractNodeTexts(node: AccessibilityNodeInfo?, list: MutableList<String>) {
        if (node == null || !node.isVisibleToUser) return

        node.text?.toString()?.trim()?.let {
            if (it.isNotEmpty()) list.add(it)
        }
        node.contentDescription?.toString()?.trim()?.let {
            if (it.isNotEmpty()) list.add(it)
        }

        for (i in 0 until node.childCount) {
            extractNodeTexts(node.getChild(i), list)
        }
    }

    private fun parseAndProcessOffer(platform: String, texts: List<String>) {
        val foundPrices = mutableListOf<Double>()
        val foundDistances = mutableListOf<Double>()

        for (text in texts) {
            // Find Prices: 8.50 €, 8,50€, €8.50, 8.50 EUR, etc.
            val priceMatcher = pricePattern.matcher(text)
            while (priceMatcher.find()) {
                val group1 = priceMatcher.group(1)
                val group2 = priceMatcher.group(2)
                val rawVal = (group1 ?: group2)?.replace(',', '.') ?: continue
                rawVal.toDoubleOrNull()?.let { p ->
                    if (p in 1.5..250.0 && !foundPrices.contains(p)) foundPrices.add(p)
                }
            }

            // Find Distances in kilometers (e.g. 9.2 km)
            val distMatcher = distKmPattern.matcher(text)
            while (distMatcher.find()) {
                val rawDist = distMatcher.group(1)?.replace(',', '.') ?: continue
                rawDist.toDoubleOrNull()?.let { d ->
                    if (d in 0.1..200.0 && !foundDistances.contains(d)) foundDistances.add(d)
                }
            }

            // Find Distances in meters (e.g. 800 m = 0.8 km)
            val meterMatcher = distMeterPattern.matcher(text)
            while (meterMatcher.find()) {
                val rawMeters = meterMatcher.group(1) ?: continue
                rawMeters.toDoubleOrNull()?.let { m ->
                    val km = m / 1000.0
                    if (km in 0.05..5.0 && !foundDistances.contains(km)) foundDistances.add(km)
                }
            }
        }

        if (foundPrices.isEmpty() || foundDistances.isEmpty()) return

        // Take primary fare (highest or first plausible fare)
        val grossFare = foundPrices.first()

        // Distances: if 2 distances found (e.g. 1.5km to pickup + 6.5km trip), sum them!
        val totalDistanceKm = if (foundDistances.size >= 2) {
            // Sum pickup + trip distance
            foundDistances.take(2).sum()
        } else {
            foundDistances.first()
        }

        if (totalDistanceKm <= 0.2) return

        // Debounce: don't re-trigger if same offer within 4 seconds
        val now = System.currentTimeMillis()
        if (abs(grossFare - lastGrossFare) < 0.05 &&
            abs(totalDistanceKm - lastDistanceKm) < 0.2 &&
            now - lastOfferTimestamp < 4000L
        ) {
            return
        }

        lastGrossFare = grossFare
        lastDistanceKm = totalDistanceKm
        lastOfferTimestamp = now

        // Read driver preferences from SharedPreferences
        val prefs = getSharedPreferences("VoltDrivePrefs", Context.MODE_PRIVATE)
        val platformFeeRate = prefs.getFloat("platformFeeRate", 0.25f).toDouble()
        val energyCostPerKm = prefs.getFloat("energyCostPerKm", 0.0409f).toDouble() // Zoe 18.6 kWh/100km * 0.22€

        // Profit calculations
        val netFare = grossFare * (1.0 - platformFeeRate)
        val electricCost = totalDistanceKm * energyCostPerKm
        val netProfit = netFare - electricCost
        val netPerKm = if (totalDistanceKm > 0.0) netProfit / totalDistanceKm else 0.0

        val (verdictText, verdictColor) = when {
            netPerKm >= 0.70 -> Pair("EXCELENTE", Color.parseColor("#00E676")) // Neon Green
            netPerKm >= 0.50 -> Pair("ACEITÁVEL", Color.parseColor("#FFB020"))  // Bright Amber
            else -> Pair("RECUSAR", Color.parseColor("#FF5252"))                // Alert Red
        }

        android.util.Log.i(
            "VoltDrive",
            "Offer detected from $platform: Gross=${grossFare}€ Dist=${totalDistanceKm}km NetProfit=${netProfit}€"
        )

        // Haptic feedback
        vibrateSubtle()

        // Show floating card overlay
        OverlayManager.showTripOffer(
            context = applicationContext,
            platform = platform,
            grossFare = grossFare,
            distanceKm = totalDistanceKm,
            netProfit = netProfit,
            netPerKm = netPerKm,
            verdictText = verdictText,
            verdictColor = verdictColor,
            electricCost = electricCost
        )
    }

    private fun vibrateSubtle() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(80, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(80)
            }
        } catch (e: Exception) {}
    }
}
