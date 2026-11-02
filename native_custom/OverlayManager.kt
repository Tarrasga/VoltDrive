package com.voltdrive.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
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
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import java.util.Locale

object OverlayManager {
    private var windowManager: WindowManager? = null
    private var currentView: View? = null
    private var borderView: View? = null
    private const val SOS_NOTIFICATION_ID = 9999
    private val handler = Handler(Looper.getMainLooper())
    private var autoDismissRunnable: Runnable? = null

    var isOverlayVisible: Boolean = false
    var currentGrossFare: Double = 0.0
    var currentDistanceKm: Double = 0.0
    var lastDismissedGrossFare: Double = 0.0
    var lastDismissedDistanceKm: Double = 0.0
    var lastDismissedTimestamp: Long = 0L

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
        isOverlayVisible = false

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

    fun hideOverlay(context: Context? = null) {
        lastDismissedGrossFare = currentGrossFare
        lastDismissedDistanceKm = currentDistanceKm
        lastDismissedTimestamp = System.currentTimeMillis()
        isOverlayVisible = false

        if (Looper.myLooper() == Looper.getMainLooper()) {
            removeCurrentViewInternal()
            hideRedBorder()
            context?.let { cancelSosNotification(it) }
        } else {
            handler.post {
                removeCurrentViewInternal()
                hideRedBorder()
                context?.let { cancelSosNotification(it) }
            }
        }
    }

    fun showRedBorder(context: Context) {
        val appContext = context.applicationContext ?: context
        if (!canDrawOverlays(appContext)) return

        handler.post {
            if (borderView != null) return@post

            val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return@post

            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT
            )

            val frame = FrameLayout(appContext)
            val strokeWidth = dpToPx(appContext, 6f)
            val borderDrawable = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                setStroke(strokeWidth, Color.parseColor("#FF0038")) // Vermelho vivo fluorescente de emergência
            }
            frame.background = borderDrawable

            // Efeito Edge Lighting: pulsação contínua da borda vermelha para chamar máxima atenção
            val anim = AlphaAnimation(1.0f, 0.30f).apply {
                duration = 650
                repeatMode = Animation.REVERSE
                repeatCount = Animation.INFINITE
            }
            frame.startAnimation(anim)

            borderView = frame
            try {
                wm.addView(frame, params)
                android.util.Log.d("VoltDrive", "Red border overlay displayed successfully!")
            } catch (e: Exception) {
                android.util.Log.e("VoltDrive", "Failed to add red border overlay: ${e.message}")
                borderView = null
            }
        }
    }

    fun hideRedBorder() {
        handler.post {
            if (borderView != null) {
                try {
                    val wm = windowManager ?: (borderView?.context?.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)
                    borderView?.clearAnimation()
                    wm?.removeView(borderView)
                    android.util.Log.d("VoltDrive", "Red border overlay removed.")
                } catch (e: Exception) {
                    android.util.Log.e("VoltDrive", "Failed to remove red border overlay: ${e.message}")
                }
                borderView = null
            }
        }
    }

    fun postSosNotification(
        context: Context,
        senderName: String,
        message: String,
        latitude: Double,
        longitude: Double
    ) {
        val appContext = context.applicationContext ?: context
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val channelId = "voltdrive_sos_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "🚨 Alertas de Emergência SOS",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificações prioritárias de pedidos de socorro TVDE com navegação GPS"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 450, 200, 450, 200, 450)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            nm.createNotificationChannel(channel)
        }

        // Action 1: Navegar no GPS (Waze / Google Maps)
        val navUri = Uri.parse("google.navigation:q=$latitude,$longitude")
        val navIntent = Intent(Intent.ACTION_VIEW, navUri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val navPendingIntent = PendingIntent.getActivity(
            appContext,
            101,
            navIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Action 2: Abrir WhatsApp diretamente
        val waIntent = appContext.packageManager.getLaunchIntentForPackage("com.whatsapp")
            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/"))
        waIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val waPendingIntent = PendingIntent.getActivity(
            appContext,
            102,
            waIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Action 3: Tocar na notificação abre o VoltDrive
        val openIntent = Intent(appContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            appContext,
            100,
            openIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val iconRes = appContext.applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_dialog_alert

        val builder = NotificationCompat.Builder(appContext, channelId)
            .setSmallIcon(iconRes)
            .setContentTitle("🚨 SOS: $senderName precisa de apoio!")
            .setContentText(if (message.isNotEmpty() && !message.contains("null")) message else "Localização GPS recebida. Toca para prestar auxílio.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setColor(Color.parseColor("#EF4444"))
            .setColorized(true)
            .setContentIntent(openPendingIntent)
            .addAction(0, "🧭 NAVEGAR (GPS)", navPendingIntent)
            .addAction(0, "💬 WHATSAPP", waPendingIntent)
            .setVibrate(longArrayOf(0, 450, 200, 450, 200, 450))

        nm.notify(SOS_NOTIFICATION_ID, builder.build())
    }

    fun cancelSosNotification(context: Context) {
        val appContext = context.applicationContext ?: context
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(SOS_NOTIFICATION_ID)
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

            val displayMetrics = appContext.resources.displayMetrics
            val isLandscape = displayMetrics.widthPixels > displayMetrics.heightPixels
            val overlayWidth = if (isLandscape) {
                // Em horizontal, limita a largura a 460dp para apresentação elegante
                dpToPx(appContext, 460f).coerceAtMost(displayMetrics.widthPixels)
            } else {
                WindowManager.LayoutParams.MATCH_PARENT
            }

            val params = WindowManager.LayoutParams(
                overlayWidth,
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

            val pauseBtn = TextView(appContext).apply {
                text = "⏸"
                textSize = 14f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                val btnBg = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#475569")) // Slate circle
                }
                background = btnBg
                gravity = Gravity.CENTER
                val p = LinearLayout.LayoutParams(dpToPx(appContext, 32f), dpToPx(appContext, 32f))
                p.setMargins(0, 0, dpToPx(appContext, 8f), 0)
                layoutParams = p
                isClickable = true
                isFocusable = false
                setOnClickListener {
                    android.util.Log.d("VoltDrive", "Pause button clicked - stopping screen reader.")
                    VoltAccessibilityService.isReadingPaused = true
                    val prefs = appContext.getSharedPreferences("voltdrive_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("screen_reader_paused", true).apply()
                    hideOverlay()
                    Toast.makeText(appContext, "⏹️ Leitor VoltDrive em pausa", Toast.LENGTH_SHORT).show()
                }
            }

            val closeBtn = TextView(appContext).apply {
                text = "✕"
                textSize = 15f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                val btnBg = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#334155")) // Slate circle
                }
                background = btnBg
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(dpToPx(appContext, 32f), dpToPx(appContext, 32f))
                isClickable = true
                isFocusable = false
                setOnClickListener {
                    android.util.Log.d("VoltDrive", "Close button clicked - dismissing overlay.")
                    hideOverlay()
                }
            }

            headerRow.addView(platformChip)
            headerRow.addView(appTitle)
            headerRow.addView(pauseBtn)
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
                text = if (electricCost > 0.0) {
                    String.format(
                        Locale.ROOT,
                        "Bruto: %.2f €  |  Distância: %.1f km  |  Custo Zoe: -%.2f €",
                        grossFare,
                        distanceKm,
                        electricCost
                    )
                } else {
                    String.format(
                        Locale.ROOT,
                        "Bruto: %.2f €  |  Líquido: %.2f €  |  Distância: %.1f km",
                        grossFare,
                        netProfit,
                        distanceKm
                    )
                }
                textSize = 11f
                setTextColor(Color.parseColor("#94A3B8"))
                setPadding(0, dpToPx(appContext, 4f), 0, 0)
            }
            card.addView(footerRow)

            // Draggable touch listener: permite reposicionar a janela sem abrir a app VoltDrive
            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f
            var hasMoved = false

            card.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        hasMoved = false
                        false // Permite que os filhos (ex: botão ✕) recebam os cliques normalmente!
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (kotlin.math.abs(dx) > 10 || kotlin.math.abs(dy) > 10) {
                            hasMoved = true
                            params.x = initialX + dx
                            params.y = initialY + dy
                            try {
                                wm.updateViewLayout(root, params)
                            } catch (e: Exception) {}
                            true
                        } else {
                            false
                        }
                    }
                    MotionEvent.ACTION_UP -> {
                        hasMoved // Nunca abrir a aplicação VoltDrive ao tocar no cartão!
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

            // Auto-dismiss configurável (padrão 12 segundos)
            val prefs = appContext.getSharedPreferences("VoltDrivePrefs", Context.MODE_PRIVATE)
            val timeoutSec = prefs.getInt("overlayTimeoutSeconds", 12)
            val timeoutMs = (timeoutSec.coerceIn(5, 30)) * 1000L

            autoDismissRunnable = Runnable { hideOverlay() }
            handler.postDelayed(autoDismissRunnable!!, timeoutMs)
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

    fun showSosAlert(
        context: Context,
        senderName: String,
        message: String,
        latitude: Double,
        longitude: Double
    ): Boolean {
        val appContext = context.applicationContext ?: context

        // 1. DISPARAR SEMPRE NOTIFICAÇÃO NATIVA DO SISTEMA ANDROID COM ALTA PRIORIDADE E BOTÕES
        postSosNotification(appContext, senderName, message, latitude, longitude)

        // 2. SE NÃO TEM PERMISSÃO DE OVERLAY, REGISTA AVISO (A NOTIFICAÇÃO DO ANDROID JÁ DISPAROU)
        if (!canDrawOverlays(appContext)) {
            android.util.Log.w("VoltDrive", "Cannot draw overlays: permission not granted! Notification posted instead.")
            return false
        }

        // 3. ATIVAR A LINHA VERMELHA DE EMERGÊNCIA (EDGE LIGHTING) A PISCAR À VOLTA DO ECRÃ
        showRedBorder(appContext)

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

            val displayMetrics = appContext.resources.displayMetrics
            val isLandscape = displayMetrics.widthPixels > displayMetrics.heightPixels
            val overlayWidth = if (isLandscape) {
                dpToPx(appContext, 460f).coerceAtMost(displayMetrics.widthPixels)
            } else {
                WindowManager.LayoutParams.MATCH_PARENT
            }

            val params = WindowManager.LayoutParams(
                overlayWidth,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                android.graphics.PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dpToPx(appContext, 36f)
            }

            // Vibrate warning pattern for emergency
            try {
                val vibrator = appContext.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                if (vibrator != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(android.os.VibrationEffect.createWaveform(longArrayOf(0, 300, 150, 300), -1))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(600)
                    }
                }
            } catch (_: Exception) {}

            // Outer Container
            val root = FrameLayout(appContext).apply {
                setPadding(dpToPx(appContext, 14f), dpToPx(appContext, 8f), dpToPx(appContext, 14f), dpToPx(appContext, 8f))
            }

            // Card Container (Dark OLED styled card with bold red border)
            val card = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                val bg = GradientDrawable().apply {
                    setColor(Color.parseColor("#1C0F13"))
                    cornerRadius = dpToPx(appContext, 18f).toFloat()
                    setStroke(dpToPx(appContext, 2.5f), Color.parseColor("#EF4444"))
                }
                background = bg
                setPadding(dpToPx(appContext, 16f), dpToPx(appContext, 14f), dpToPx(appContext, 16f), dpToPx(appContext, 14f))
            }

            // Header Row: SOS Badge + Title + Close Button
            val headerRow = LinearLayout(appContext).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }

            val sosBadge = TextView(appContext).apply {
                text = " 🚨 SOS URGENTE "
                textSize = 12f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                val chipBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#DC2626"))
                    cornerRadius = dpToPx(appContext, 6f).toFloat()
                }
                background = chipBg
                setPadding(dpToPx(appContext, 8f), dpToPx(appContext, 3f), dpToPx(appContext, 8f), dpToPx(appContext, 3f))
            }

            val headerTitle = TextView(appContext).apply {
                text = "  REDE TVDE"
                textSize = 12f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#FCA5A5"))
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            }

            val closeBtn = TextView(appContext).apply {
                text = "✕"
                textSize = 15f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                val btnBg = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#334155"))
                }
                background = btnBg
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(dpToPx(appContext, 32f), dpToPx(appContext, 32f))
                isClickable = true
                isFocusable = false
                setOnClickListener { hideOverlay(appContext) }
            }

            headerRow.addView(sosBadge)
            headerRow.addView(headerTitle)
            headerRow.addView(closeBtn)
            card.addView(headerRow)

            // Colleague Name and Alert text
            val nameText = TextView(appContext).apply {
                text = "$senderName precisa de apoio!"
                textSize = 17f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                setPadding(0, dpToPx(appContext, 10f), 0, dpToPx(appContext, 4f))
            }
            card.addView(nameText)

            val detailText = TextView(appContext).apply {
                text = if (message.isNotEmpty() && !message.contains("null")) message else "Alerta de emergência disparado via VoltDrive"
                textSize = 13f
                setTextColor(Color.parseColor("#CBD5E1"))
                setPadding(0, 0, 0, dpToPx(appContext, 12f))
            }
            card.addView(detailText)

            // Buttons row: [ 🧭 Navegar no GPS ] [ 💬 WhatsApp ]
            val btnRow = LinearLayout(appContext).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }

            // Button 1: Navegar no GPS
            val navBtn = TextView(appContext).apply {
                text = "🧭 NAVEGAR (GPS)"
                textSize = 13f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.BLACK)
                gravity = Gravity.CENTER
                val btnBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#00E676"))
                    cornerRadius = dpToPx(appContext, 10f).toFloat()
                }
                background = btnBg
                setPadding(dpToPx(appContext, 12f), dpToPx(appContext, 10f), dpToPx(appContext, 12f), dpToPx(appContext, 10f))
                val p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
                p.setMargins(0, 0, dpToPx(appContext, 8f), 0)
                layoutParams = p
                isClickable = true
                isFocusable = false
                setOnClickListener {
                    try {
                        val navUri = Uri.parse("google.navigation:q=$latitude,$longitude")
                        val navIntent = Intent(Intent.ACTION_VIEW, navUri).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        appContext.startActivity(navIntent)
                    } catch (e: Exception) {
                        try {
                            val mapUri = Uri.parse("https://maps.google.com/?q=$latitude,$longitude")
                            val mapIntent = Intent(Intent.ACTION_VIEW, mapUri).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            appContext.startActivity(mapIntent)
                        } catch (_: Exception) {}
                    }
                    hideOverlay(appContext)
                }
            }

            // Button 2: WhatsApp
            val waBtn = TextView(appContext).apply {
                text = "💬 WHATSAPP"
                textSize = 13f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                val btnBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#25D366"))
                    cornerRadius = dpToPx(appContext, 10f).toFloat()
                }
                background = btnBg
                setPadding(dpToPx(appContext, 12f), dpToPx(appContext, 10f), dpToPx(appContext, 12f), dpToPx(appContext, 10f))
                val p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
                layoutParams = p
                isClickable = true
                isFocusable = false
                setOnClickListener {
                    try {
                        val waIntent = appContext.packageManager.getLaunchIntentForPackage("com.whatsapp")
                        if (waIntent != null) {
                            waIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            appContext.startActivity(waIntent)
                        }
                    } catch (_: Exception) {}
                    hideOverlay(appContext)
                }
            }

            btnRow.addView(navBtn)
            btnRow.addView(waBtn)
            card.addView(btnRow)

            root.addView(card)
            currentView = root

            try {
                wm.addView(root, params)
                isOverlayVisible = true
                android.util.Log.d("VoltDrive", "SOS Overlay view displayed successfully!")
            } catch (e: Exception) {
                android.util.Log.e("VoltDrive", "Error displaying SOS overlay: ${e.message}", e)
                currentView = null
                return@post
            }

            // Auto-dismiss após 45 segundos
            autoDismissRunnable = Runnable { hideOverlay(appContext) }
            handler.postDelayed(autoDismissRunnable!!, 45000L)
        }
        return true
    }
}
