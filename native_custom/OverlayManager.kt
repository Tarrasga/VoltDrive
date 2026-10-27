package com.voltdrive.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

object OverlayManager {
    private var windowManager: WindowManager? = null
    private var currentView: View? = null
    private val handler = Handler(Looper.getMainLooper())
    private var autoDismissRunnable: Runnable? = null

    private fun dpToPx(context: Context, dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            context.resources.displayMetrics
        ).toInt()
    }

    fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    private fun removeCurrentViewInternal() {
        autoDismissRunnable?.let { handler.removeCallbacks(it) }
        autoDismissRunnable = null

        if (currentView != null && windowManager != null) {
            try {
                windowManager?.removeView(currentView)
                android.util.Log.d("VoltDrive", "Overlay view removed successfully.")
            } catch (e: Exception) {
                android.util.Log.e("VoltDrive", "Failed to remove overlay view: ${e.message}")
            }
            currentView = null
        }
    }

    fun hideOverlay() {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            removeCurrentViewInternal()
        } else {
            handler.post { removeCurrentViewInternal() }
        }
    }

    fun showTripOffer(
        context: Context,
        platform: String,
        grossFare: Double,
        distanceKm: Double,
        netProfit: Double,
        netPerKm: Double,
        verdictText: String,
        verdictColor: Int,
        electricCost: Double
    ): Boolean {
        val appContext = context.applicationContext ?: context
        if (!canDrawOverlays(appContext)) {
            android.util.Log.w("VoltDrive", "Cannot draw overlays: permission not granted!")
            return false
        }

        handler.post {
            removeCurrentViewInternal()

            val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return@post
            windowManager = wm

            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                android.graphics.PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dpToPx(appContext, 48f)
            }

            // Outer Container with touch/drag support
            val root = FrameLayout(appContext).apply {
                setPadding(dpToPx(appContext, 16f), dpToPx(appContext, 8f), dpToPx(appContext, 16f), dpToPx(appContext, 8f))
            }

            // Card Container (Dark OLED styled card with colored border)
            val card = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                val bg = GradientDrawable().apply {
                    setColor(Color.parseColor("#171B26")) // Dark background
                    cornerRadius = dpToPx(appContext, 18f).toFloat()
                    setStroke(dpToPx(appContext, 2f), verdictColor)
                }
                background = bg
                setPadding(dpToPx(appContext, 16f), dpToPx(appContext, 14f), dpToPx(appContext, 16f), dpToPx(appContext, 14f))
            }

            // Header Row: Platform Badge + Title + Close Button
            val headerRow = LinearLayout(appContext).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }

            // Platform chip (Uber = Black/White, Bolt = Green)
            val isBolt = platform.uppercase(Locale.ROOT).contains("BOLT")
            val platformChip = TextView(appContext).apply {
                text = if (isBolt) " BOLT " else " UBER "
                textSize = 11f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(if (isBolt) Color.BLACK else Color.WHITE)
                val chipBg = GradientDrawable().apply {
                    setColor(if (isBolt) Color.parseColor("#00D665") else Color.parseColor("#000000"))
                    cornerRadius = dpToPx(appContext, 6f).toFloat()
                    if (!isBolt) setStroke(dpToPx(appContext, 1f), Color.WHITE)
                }
                background = chipBg
                setPadding(dpToPx(appContext, 6f), dpToPx(appContext, 2f), dpToPx(appContext, 6f), dpToPx(appContext, 2f))
            }

            val appTitle = TextView(appContext).apply {
                text = "  ⚡ VoltDrive  •  Renault Zoe"
                textSize = 12f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#94A3B8"))
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            }

            val closeBtn = TextView(appContext).apply {
                text = "✕"
                textSize = 16f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#94A3B8"))
                setPadding(dpToPx(appContext, 8f), 0, dpToPx(appContext, 4f), 0)
                setOnClickListener { hideOverlay() }
            }

            headerRow.addView(platformChip)
            headerRow.addView(appTitle)
            headerRow.addView(closeBtn)
            card.addView(headerRow)

            // Main Metrics Row
            val metricsRow = LinearLayout(appContext).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dpToPx(appContext, 10f), 0, dpToPx(appContext, 8f))
            }

            // Left: Big Net Profit
            val profitCol = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            }

            val netProfitText = TextView(appContext).apply {
                text = String.format(Locale.ROOT, "+%.2f €", netProfit)
                textSize = 26f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(verdictColor)
            }

            val netLabel = TextView(appContext).apply {
                text = "LÚCRO LÍQUIDO LIMPO"
                textSize = 10f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#64748B"))
            }

            profitCol.addView(netProfitText)
            profitCol.addView(netLabel)

            // Right: €/Km & Verdict Badge
            val ratingCol = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.END
            }

            val perKmText = TextView(appContext).apply {
                text = String.format(Locale.ROOT, "%.2f €/km", netPerKm)
                textSize = 18f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
            }

            val verdictBadge = TextView(appContext).apply {
                text = " $verdictText "
                textSize = 11f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.BLACK)
                val badgeBg = GradientDrawable().apply {
                    setColor(verdictColor)
                    cornerRadius = dpToPx(appContext, 6f).toFloat()
                }
                background = badgeBg
                setPadding(dpToPx(appContext, 8f), dpToPx(appContext, 2f), dpToPx(appContext, 8f), dpToPx(appContext, 2f))
            }

            ratingCol.addView(perKmText)
            ratingCol.addView(verdictBadge)

            metricsRow.addView(profitCol)
            metricsRow.addView(ratingCol)
            card.addView(metricsRow)

            // Details Footer Row
            val footerRow = TextView(appContext).apply {
                text = String.format(
                    Locale.ROOT,
                    "Bruto: %.2f €  |  Distância: %.1f km  |  Custo Zoe: -%.2f €",
                    grossFare,
                    distanceKm,
                    electricCost
                )
                textSize = 11f
                setTextColor(Color.parseColor("#94A3B8"))
                setPadding(0, dpToPx(appContext, 4f), 0, 0)
            }
            card.addView(footerRow)

            // Draggable touch listener with click handling
            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f

            card.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        params.x = initialX + dx
                        params.y = initialY + dy
                        try {
                            wm.updateViewLayout(root, params)
                        } catch (e: Exception) {}
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        val diffX = kotlin.math.abs(event.rawX - initialTouchX)
                        val diffY = kotlin.math.abs(event.rawY - initialTouchY)
                        if (diffX < dpToPx(appContext, 10f) && diffY < dpToPx(appContext, 10f)) {
                            // User tapped card: open VoltDrive
                            try {
                                val launchIntent = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
                                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                appContext.startActivity(launchIntent)
                                hideOverlay()
                            } catch (e: Exception) {}
                        }
                        true
                    }
                    else -> false
                }
            }

            root.addView(card)
            currentView = root

            try {
                wm.addView(root, params)
                android.util.Log.d("VoltDrive", "Overlay view successfully displayed!")
            } catch (e: Exception) {
                android.util.Log.e("VoltDrive", "Error adding overlay view: ${e.message}", e)
                currentView = null
                return@post
            }

            // Auto-dismiss after 15 seconds
            autoDismissRunnable = Runnable { hideOverlay() }
            handler.postDelayed(autoDismissRunnable!!, 15000)
        }
        return true
    }

    fun showTestOffer(context: Context): Boolean {
        return showTripOffer(
            context = context,
            platform = "BOLT",
            grossFare = 8.50,
            distanceKm = 9.2,
            netProfit = 6.00,
            netPerKm = 0.65,
            verdictText = "ACEITÁVEL",
            verdictColor = Color.parseColor("#FFB020"),
            electricCost = 0.38
        )
    }
}
