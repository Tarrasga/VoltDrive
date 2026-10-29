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
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
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
                "getTvdeAppsStatus" -> {
                    val isUber = isPackageInstalled("com.ubercab.driver")
                    val isBolt = isPackageInstalled("ee.mtakso.driver") || isPackageInstalled("com.bolt.driver")
                    val res = mapOf(
                        "uberInstalled" to isUber,
                        "boltInstalled" to isBolt,
                        "uberLastSeen" to VoltAccessibilityService.lastUberDetectedTime,
                        "boltLastSeen" to VoltAccessibilityService.lastBoltDetectedTime
                    )
                    result.success(res)
                }
                "exportMonthlyPdf" -> {
                    try {
                        val monthName = call.argument<String>("monthName") ?: "Mês"
                        val month = call.argument<Int>("month") ?: 1
                        val year = call.argument<Int>("year") ?: 2026
                        val totalGross = call.argument<Double>("totalGross") ?: 0.0
                        val uberGross = call.argument<Double>("uberGross") ?: 0.0
                        val boltGross = call.argument<Double>("boltGross") ?: 0.0
                        val tips = call.argument<Double>("tips") ?: 0.0
                        val platformFees = call.argument<Double>("platformFees") ?: 0.0
                        val chargingCost = call.argument<Double>("chargingCost") ?: 0.0
                        val chargingKwh = call.argument<Double>("chargingKwh") ?: 0.0
                        val tollsCost = call.argument<Double>("tollsCost") ?: 0.0
                        val otherExpenses = call.argument<Double>("otherExpenses") ?: 0.0
                        val totalExpenses = call.argument<Double>("totalExpenses") ?: 0.0
                        val netProfit = call.argument<Double>("netProfit") ?: 0.0
                        val totalKm = call.argument<Double>("totalKm") ?: 0.0
                        val totalHours = call.argument<Double>("totalHours") ?: 0.0
                        val profitPerKm = call.argument<Double>("profitPerKm") ?: 0.0
                        val profitPerHour = call.argument<Double>("profitPerHour") ?: 0.0
                        val shifts = call.argument<List<Map<String, Any>>>("shifts") ?: emptyList()

                        generateAndOpenMonthlyPdf(
                            monthName, month, year, totalGross, uberGross, boltGross, tips,
                            platformFees, chargingCost, chargingKwh, tollsCost, otherExpenses,
                            totalExpenses, netProfit, totalKm, totalHours, profitPerKm, profitPerHour,
                            shifts
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("VoltDrive", "Error generating PDF: ${e.message}", e)
                        result.error("PDF_ERROR", e.message, null)
                    }
                }
                "shareBackupFile" -> {
                    try {
                        val fileName = call.argument<String>("fileName") ?: "voltdrive_backup.json"
                        val content = call.argument<String>("content") ?: ""
                        val file = File(cacheDir, fileName)
                        file.writeText(content, Charsets.UTF_8)
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this@MainActivity,
                            "$packageName.fileprovider",
                            file
                        )
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/json"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra(Intent.EXTRA_SUBJECT, "Cópia de Segurança VoltDrive")
                            putExtra(Intent.EXTRA_TEXT, "Cópia de segurança dos dados do VoltDrive para troca de telemóvel.")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(sendIntent, "Guardar Cópia de Segurança VoltDrive")
                        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("VoltDrive", "Error sharing backup: ${e.message}", e)
                        result.error("BACKUP_ERROR", e.message, null)
                    }
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

                        var started = false

                        // Se for para um número específico (conversa direta)
                        if (finalPhone.isNotEmpty()) {
                            val url = "https://api.whatsapp.com/send?phone=$finalPhone&text=$encoded"
                            try {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    setPackage("com.whatsapp")
                                }
                                startActivity(intent)
                                started = true
                            } catch (e: Exception) {
                                try {
                                    val bIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        setPackage("com.whatsapp.w4b")
                                    }
                                    startActivity(bIntent)
                                    started = true
                                } catch (e2: Exception) {}
                            }
                        }

                        // Se for para Grupo ou escolha de conversa no WhatsApp (ACTION_SEND direto)
                        if (!started) {
                            try {
                                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, message)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    setPackage("com.whatsapp")
                                }
                                startActivity(sendIntent)
                                started = true
                            } catch (e: Exception) {
                                try {
                                    val bSendIntent = Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_TEXT, message)
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        setPackage("com.whatsapp.w4b")
                                    }
                                    startActivity(bSendIntent)
                                    started = true
                                } catch (e2: Exception) {
                                    val url = if (finalPhone.isNotEmpty()) {
                                        "https://api.whatsapp.com/send?phone=$finalPhone&text=$encoded"
                                    } else {
                                        "https://api.whatsapp.com/send?text=$encoded"
                                    }
                                    val fallback = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(fallback)
                                    started = true
                                }
                            }
                        }

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
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        val vName = pInfo.versionName ?: "1.0.41"
                        result.success(vName)
                    } catch (e: Exception) {
                        result.success("1.0.41")
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

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun generateAndOpenMonthlyPdf(
        monthName: String,
        month: Int,
        year: Int,
        totalGross: Double,
        uberGross: Double,
        boltGross: Double,
        tips: Double,
        platformFees: Double,
        chargingCost: Double,
        chargingKwh: Double,
        tollsCost: Double,
        otherExpenses: Double,
        totalExpenses: Double,
        netProfit: Double,
        totalKm: Double,
        totalHours: Double,
        profitPerKm: Double,
        profitPerHour: Double,
        shifts: List<Map<String, Any>>
    ) {
        val pdfDocument = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas

        val paint = Paint().apply { isAntiAlias = true }

        // Fundo Branco
        canvas.drawColor(Color.WHITE)

        // Banner de Cabeçalho Superior
        paint.color = Color.parseColor("#0F172A") // Slate escuro
        paint.style = Paint.Style.FILL
        canvas.drawRect(0f, 0f, 595f, 75f, paint)

        // Linha Ciano Elétrico
        paint.color = Color.parseColor("#00D2FF")
        canvas.drawRect(0f, 72f, 595f, 75f, paint)

        // Título e Subtítulo
        paint.color = Color.WHITE
        paint.textSize = 17f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("VOLTDRIVE TVDE - RELATÓRIO MENSAL", 30f, 38f, paint)

        paint.color = Color.parseColor("#94A3B8")
        paint.textSize = 9f
        paint.typeface = Typeface.DEFAULT
        canvas.drawText("Renault Zoe Z.E. 50 Edition • Gestão de Faturação e Rentabilidade Elétrica", 30f, 56f, paint)

        // Etiqueta do Mês
        paint.color = Color.parseColor("#00D2FF")
        paint.textSize = 13f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        paint.textAlign = Paint.Align.RIGHT
        canvas.drawText(monthName.uppercase(Locale.ROOT), 565f, 44f, paint)
        paint.textAlign = Paint.Align.LEFT

        // 4 Cartões KPI Principais
        fun drawKpiCard(x: Float, y: Float, w: Float, h: Float, title: String, value: String, valColor: Int) {
            paint.color = Color.parseColor("#F8FAFC")
            paint.style = Paint.Style.FILL
            canvas.drawRoundRect(RectF(x, y, x + w, y + h), 8f, 8f, paint)

            paint.color = Color.parseColor("#E2E8F0")
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1f
            canvas.drawRoundRect(RectF(x, y, x + w, y + h), 8f, 8f, paint)

            paint.style = Paint.Style.FILL
            paint.color = Color.parseColor("#64748B")
            paint.textSize = 8f
            paint.typeface = Typeface.DEFAULT_BOLD
            canvas.drawText(title, x + 8f, y + 18f, paint)

            paint.color = valColor
            paint.textSize = 14f
            paint.typeface = Typeface.DEFAULT_BOLD
            canvas.drawText(value, x + 8f, y + 42f, paint)
        }

        val cardW = 125f
        val cardH = 55f
        val cardY = 90f
        drawKpiCard(30f, cardY, cardW, cardH, "FATURAÇÃO BRUTA", String.format(Locale.ROOT, "%.2f €", totalGross), Color.parseColor("#0F172A"))
        drawKpiCard(165f, cardY, cardW, cardH, "TAXAS PLATAFORMA", String.format(Locale.ROOT, "-%.2f €", platformFees), Color.parseColor("#DC2626"))
        drawKpiCard(300f, cardY, cardW, cardH, "DESPESAS TOTAIS", String.format(Locale.ROOT, "-%.2f €", totalExpenses), Color.parseColor("#D97706"))
        drawKpiCard(435f, cardY, cardW, cardH, "LUCRO LÍQUIDO", String.format(Locale.ROOT, "+%.2f €", netProfit), Color.parseColor("#16A34A"))

        // Painel Resumo Operacional (Km, Horas, Médias e Consumo)
        val metricsY = 160f
        paint.color = Color.parseColor("#F1F5F9")
        paint.style = Paint.Style.FILL
        canvas.drawRoundRect(RectF(30f, metricsY, 565f, metricsY + 44f), 8f, 8f, paint)

        paint.color = Color.parseColor("#0F172A")
        paint.textSize = 9f
        paint.typeface = Typeface.DEFAULT
        val col1 = if (uberGross > 0 || boltGross > 0) {
            String.format(Locale.ROOT, "Uber: %.2f €  •  Bolt: %.2f €  •  Gorjetas: %.2f €", uberGross, boltGross, tips)
        } else {
            String.format(Locale.ROOT, "Faturação Total: %.2f €  •  Gorjetas Extras: %.2f €", totalGross, tips)
        }
        val col2 = String.format(Locale.ROOT, "Km Totais: %.0f km  •  Horas: %.1f h  •  Média: %.2f €/km  •  Média: %.2f €/h", totalKm, totalHours, profitPerKm, profitPerHour)
        val col3 = String.format(Locale.ROOT, "Carregamento VE: %.2f € (%.1f kWh)  •  Portagens: %.2f €  •  Outros: %.2f €", chargingCost, chargingKwh, tollsCost, otherExpenses)

        canvas.drawText(col1, 40f, metricsY + 14f, paint)
        canvas.drawText(col2, 40f, metricsY + 27f, paint)
        canvas.drawText(col3, 40f, metricsY + 40f, paint)

        // Tabela Diária
        val tableY = 220f
        paint.color = Color.parseColor("#0F172A")
        paint.textSize = 11f
        paint.typeface = Typeface.DEFAULT_BOLD
        canvas.drawText("DETALHE DIÁRIO DE TURNOS", 30f, tableY, paint)

        val headerY = tableY + 8f
        paint.color = Color.parseColor("#1E293B")
        paint.style = Paint.Style.FILL
        canvas.drawRect(30f, headerY, 565f, headerY + 18f, paint)

        paint.color = Color.WHITE
        paint.textSize = 8f
        paint.typeface = Typeface.DEFAULT_BOLD
        canvas.drawText("DATA", 35f, headerY + 12f, paint)
        canvas.drawText("FATURADO", 95f, headerY + 12f, paint)
        canvas.drawText("KM", 180f, headerY + 12f, paint)
        canvas.drawText("HORAS", 235f, headerY + 12f, paint)
        canvas.drawText("CARREG.", 295f, headerY + 12f, paint)
        canvas.drawText("PORTAG.", 365f, headerY + 12f, paint)
        canvas.drawText("OUTROS", 435f, headerY + 12f, paint)
        canvas.drawText("LUCRO LÍQ.", 500f, headerY + 12f, paint)

        var curRowY = headerY + 18f
        val rowH = 15f
        var rowIdx = 0

        for (s in shifts) {
            if (curRowY > 780f) break // Limite seguro da página A4

            paint.color = if (rowIdx % 2 == 0) Color.WHITE else Color.parseColor("#F8FAFC")
            paint.style = Paint.Style.FILL
            canvas.drawRect(30f, curRowY, 565f, curRowY + rowH, paint)

            paint.color = Color.parseColor("#334155")
            paint.textSize = 7.5f
            paint.typeface = Typeface.DEFAULT

            val dateStr = s["date"] as? String ?: ""
            val g = (s["gross"] as? Number)?.toDouble() ?: 0.0
            val km = (s["km"] as? Number)?.toDouble() ?: 0.0
            val h = (s["hours"] as? Number)?.toDouble() ?: 0.0
            val c = (s["charging"] as? Number)?.toDouble() ?: 0.0
            val t = (s["tolls"] as? Number)?.toDouble() ?: 0.0
            val o = (s["otherExpenses"] as? Number)?.toDouble() ?: 0.0
            val n = (s["net"] as? Number)?.toDouble() ?: 0.0

            canvas.drawText(dateStr, 35f, curRowY + 10.5f, paint)
            canvas.drawText(String.format(Locale.ROOT, "%.2f €", g), 95f, curRowY + 10.5f, paint)
            canvas.drawText(String.format(Locale.ROOT, "%.0f km", km), 180f, curRowY + 10.5f, paint)
            canvas.drawText(String.format(Locale.ROOT, "%.1f h", h), 235f, curRowY + 10.5f, paint)
            canvas.drawText(String.format(Locale.ROOT, "%.2f €", c), 295f, curRowY + 10.5f, paint)
            canvas.drawText(String.format(Locale.ROOT, "%.2f €", t), 365f, curRowY + 10.5f, paint)
            canvas.drawText(String.format(Locale.ROOT, "%.2f €", o), 435f, curRowY + 10.5f, paint)

            paint.color = if (n >= 0) Color.parseColor("#16A34A") else Color.parseColor("#DC2626")
            paint.typeface = Typeface.DEFAULT_BOLD
            canvas.drawText(String.format(Locale.ROOT, "%.2f €", n), 500f, curRowY + 10.5f, paint)

            curRowY += rowH
            rowIdx++
        }

        // Linha de Totais da Tabela
        paint.color = Color.parseColor("#E2E8F0")
        paint.style = Paint.Style.FILL
        canvas.drawRect(30f, curRowY, 565f, curRowY + 18f, paint)

        paint.color = Color.parseColor("#0F172A")
        paint.textSize = 8f
        paint.typeface = Typeface.DEFAULT_BOLD
        canvas.drawText("TOTAIS:", 35f, curRowY + 12f, paint)
        canvas.drawText(String.format(Locale.ROOT, "%.2f €", totalGross), 95f, curRowY + 12f, paint)
        canvas.drawText(String.format(Locale.ROOT, "%.0f km", totalKm), 180f, curRowY + 12f, paint)
        canvas.drawText(String.format(Locale.ROOT, "%.1f h", totalHours), 235f, curRowY + 12f, paint)
        canvas.drawText(String.format(Locale.ROOT, "%.2f €", chargingCost), 295f, curRowY + 12f, paint)
        canvas.drawText(String.format(Locale.ROOT, "%.2f €", tollsCost), 365f, curRowY + 12f, paint)
        canvas.drawText(String.format(Locale.ROOT, "%.2f €", otherExpenses), 435f, curRowY + 12f, paint)

        paint.color = Color.parseColor("#16A34A")
        canvas.drawText(String.format(Locale.ROOT, "%.2f €", netProfit), 500f, curRowY + 12f, paint)

        // Rodapé da Página
        paint.color = Color.parseColor("#94A3B8")
        paint.textSize = 8f
        paint.typeface = Typeface.DEFAULT
        val nowStr = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.ROOT).format(Date())
        canvas.drawText("VoltDrive • Documento de gestão TVDE para motorista e contabilidade • Gerado em $nowStr", 30f, 815f, paint)

        pdfDocument.finishPage(page)

        // Gravar no disco em cacheDir
        val safeMonth = monthName.replace(" ", "_").lowercase(Locale.ROOT)
        val file = File(cacheDir, "VoltDrive_Registo_Mensal_${safeMonth}.pdf")
        if (file.exists()) file.delete()

        FileOutputStream(file).use { out ->
            pdfDocument.writeTo(out)
        }
        pdfDocument.close()

        // Abrir o PDF com o Intent do Android (Acrobat, Drive PDF, Samsung, etc.)
        val uri = androidx.core.content.FileProvider.getUriForFile(
            this@MainActivity,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val chooser = Intent.createChooser(intent, "Abrir Relatório Mensal PDF").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(chooser)
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
