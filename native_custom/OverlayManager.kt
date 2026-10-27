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

    fun hideOverlay() {
        handler.post {
            autoDismissRunnable?.let { handler.removeCallbacks(it) }
            autoDismissRunnable = null

            if (currentView != null && windowManager != null) {
                try {
                    windowManager?.removeView(currentView)
                } catch (e: Exception) {
                }
                currentView = null
            }
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
    ) {
        if (!canDrawOverlays(context)) return

        handler.post {
            hideOverlay()

            val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return@post
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
                y = dpToPx(context, 48f)
            }

            // Outer Container with touch/drag support
            val root = FrameLayout(context).apply {
                setPadding(dpToPx(context, 16f), dpToPx(context, 8f), dpToPx(context, 16f), dpToPx(context, 8f))
            }

            // Card Container (Dark OLED styled card with colored border)
            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                val bg = GradientDrawable().apply {
                    setColor(Color.parseColor("#171B26")) // Dark background
                    cornerRadius = dpToPx(context, 18f).toFloat()
                    setStroke(dpToPx(context, 2f), verdictColor)
                }
                background = bg
                setPadding(dpToPx(context, 16f), dpToPx(context, 14f), dpToPx(context, 16f), dpToPx(context, 14f))
            }

            // Header Row: Platform Badge + Title + Close Button
            val headerRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }

            // Platform chip (Uber = Black/White, Bolt = Green)
            val isBolt = platform.uppercase(Locale.ROOT).contains("BOLT")
            val platformChip = TextView(context).apply {
                text = if (isBolt) " BOLT " else " UBER "
                textSize = 11f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(if (isBolt) Color.BLACK else Color.WHITE)
                val chipBg = GradientDrawable().apply {
                    setColor(if (isBolt) Color.parseColor("#00D665") else Color.parseColor("#000000"))
                    cornerRadius = dpToPx(context, 6f).toFloat()
                    if (!isBolt) setStroke(dpToPx(context, 1f), Color.WHITE)
                }
                background = chipBg
                setPadding(dpToPx(context, 6f), dpToPx(context, 2f), dpToPx(context, 6f), dpToPx(context, 2f))
            }

            val appTitle = TextView(context).apply {
                text = "  ⚡ VoltDrive  •  Renault Zoe"
                textSize = 12f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#94A3B8"))
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            }

            val closeBtn = TextView(context).apply {
                text = "✕"
                textSize = 16f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#94A3B8"))
                setPadding(dpToPx(context, 8f), 0, dpToPx(context, 4f), 0)
                setOnClickListener { hideOverlay() }
            }

            headerRow.addView(platformChip)
            headerRow.addView(appTitle)
            headerRow.addView(closeBtn)
            card.addView(headerRow)

            // Main Metrics Row
            val metricsRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dpToPx(context, 10f), 0, dpToPx(context, 8f))
            }

            // Left: Big Net Profit
            val profitCol = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            }

            val netProfitText = TextView(context).apply {
                text = String.format(Locale.ROOT, "+%.2f €", netProfit)
                textSize = 26f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(verdictColor)
            }

            val netLabel = TextView(context).apply {
                text = "LÚCRO LÍQUIDO LIMPO"
                textSize = 10f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#64748B"))
            }

            profitCol.addView(netProfitText)
            profitCol.addView(netLabel)

            // Right: €/Km & Verdict Badge
            val ratingCol = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.END
            }

            val perKmText = TextView(context).apply {
                text = String.format(Locale.ROOT, "%.2f €/km", netPerKm)
                textSize = 18f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
            }

            val verdictBadge = TextView(context).apply {
                text = " $verdictText "
                textSize = 11f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.BLACK)
                val badgeBg = GradientDrawable().apply {
                    setColor(verdictColor)
                    cornerRadius = dpToPx(context, 6f).toFloat()
                }
                background = badgeBg
                setPadding(dpToPx(context, 8f), dpToPx(context, 2f), dpToPx(context, 8f), dpToPx(context, 2f))
            }

            ratingCol.addView(perKmText)
            ratingCol.addView(verdictBadge)

            metricsRow.addView(profitCol)
            metricsRow.addView(ratingCol)
            card.addView(metricsRow)

            // Details Footer Row
            val footerRow = TextView(context).apply {
                text = String.format(
                    Locale.ROOT,
                    "Bruto: %.2f €  |  Distância: %.1f km  |  Custo Zoe: -%.2f €",
                    grossFare,
                    distanceKm,
                    electricCost
                )
                textSize = 11f
                setTextColor(Color.parseColor("#94A3B8"))
                setPadding(0, dpToPx(context, 4f), 0, 0)
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
                        if (diffX < dpToPx(context, 10f) && diffY < dpToPx(context, 10f)) {
                            // User tapped card: open VoltDrive
                            try {
                                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                context.startActivity(launchIntent)
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
            } catch (e: Exception) {
                currentView = null
                return@post
            }

            // Auto-dismiss after 15 seconds
            autoDismissRunnable = Runnable { hideOverlay() }
            handler.postDelayed(autoDismissRunnable!!, 15000)
        }
    }

    fun showTestOffer(context: Context) {
        showTripOffer(
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
