package com.voltdrive.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Locale
import java.util.regex.Pattern
import kotlin.math.abs

class VoltAccessibilityService : AccessibilityService() {

    companion object {
        var instance: VoltAccessibilityService? = null
        var isServiceRunning = false
        var isReadingPaused = false
        var lastOfferTimestamp = 0L
        var lastGrossFare = 0.0
        var lastDistanceKm = 0.0
        var lastUberDetectedTime = 0L
        var lastBoltDetectedTime = 0L
    }

    private val pricePattern = Pattern.compile("(?:(?:€|EUR)\\s*([0-9]+[.,][0-9]{2})|([0-9]+[.,][0-9]{2})\\s*(?:€|EUR))", Pattern.CASE_INSENSITIVE)
    private val distKmPattern = Pattern.compile("([0-9]+[.,]?[0-9]*)\\s*km\\b", Pattern.CASE_INSENSITIVE)
    private val distMeterPattern = Pattern.compile("\\b([0-9]{2,4})\\s*m\\b", Pattern.CASE_INSENSITIVE)

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        isServiceRunning = true
        val prefs = getSharedPreferences("voltdrive_prefs", Context.MODE_PRIVATE)
        isReadingPaused = prefs.getBoolean("screen_reader_paused", false)
        android.util.Log.i("VoltDrive", "VoltAccessibilityService connected, isReadingPaused=$isReadingPaused")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isServiceRunning = false
        OverlayManager.hideOverlay()
        android.util.Log.i("VoltDrive", "VoltAccessibilityService destroyed.")
    }

    override fun onInterrupt() {
        isServiceRunning = false
    }

    private fun isTripOfferScreen(texts: List<String>): Boolean {
        val fullText = texts.joinToString(" ").lowercase(Locale.ROOT)

        // 1. TERMOS ESTRITOS DE NAVEGAÇÃO GPS E VIAGEM EM CURSO (IGNORAR TOTALMENTE)
        // Quando a viagem já foi calculada/aceite e o GPS está ativo (ou waze/maps/rotas)
        val gpsNavigationKeywords = listOf(
            "vire", "rotunda", "saída", "siga", "conduza", "em direção", "direções",
            "metros", "m à", "km à", "em frente", "à direita", "à esquerda",
            "waze", "google maps", "gps", "recalculando", "em rota",
            "iniciar viagem", "terminar viagem", "concluir viagem", "concluir",
            "deslize para iniciar", "deslize para concluir", "deslize para confirmar",
            "chegou ao destino", "chegou à recolha", "chegou ao embarque", "a caminho",
            "em viagem", "contactar passageiro", "ligar ao", "cancelar viagem",
            "paragem", "largada", "destino final", "chegada prevista", "hora de chegada",
            "restantes", "tempo restante", "previsão"
        )
        val isGpsNavigation = gpsNavigationKeywords.any { kw -> fullText.contains(kw) }
        if (isGpsNavigation) {
            // Em navegação GPS activa: NUNCA voltar a calcular a viagem pelo GPS!
            return false
        }

        // 2. Termos típicos do ecrã inicial / mapa sem pedidos ativos (onde aparecem estatísticas diárias e km da última corrida)
        val idleKeywords = listOf(
            "ganhos de hoje", "saldo da conta", "está online", "encontrar viagens",
            "procurar passageiros", "fazer uma pausa", "definir destino", "oportunidades",
            "horas online", "conduzir", "ver detalhes da conta", "está offline"
        )
        val hasIdleKeyword = idleKeywords.any { kw -> fullText.contains(kw) }

        // 3. Termos obrigatórios de uma oferta nova a tocar no ecrã para ser aceite
        val explicitOfferKeywords = listOf(
            "aceitar", "accept", "novo pedido", "nova viagem", "nova corrida",
            "tocar para aceitar", "deslize para aceitar", "tocar para", "pedido de viagem"
        )
        val hasOfferKeyword = explicitOfferKeywords.any { kw -> fullText.contains(kw) }

        // Se tem termos de mapa/ganhos ou não tem gatilho explícito de aceitação de oferta, ignora!
        if (hasIdleKeyword || !hasOfferKeyword) {
            return false
        }

        return true
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (isReadingPaused) {
            // Leitor pausado / parado pelo utilizador
            return
        }
        val pkg = event.packageName?.toString() ?: return

        val isUber = pkg.contains("ubercab.driver")
        val isBolt = pkg.contains("mtakso.driver") || pkg.contains("bolt.driver")

        if (isUber) {
            lastUberDetectedTime = System.currentTimeMillis()
        }
        if (isBolt) {
            lastBoltDetectedTime = System.currentTimeMillis()
        }

        if (!isUber && !isBolt) return

        val textList = mutableListOf<String>()
        val rootNode = rootInActiveWindow ?: event.source
        if (rootNode != null) {
            extractNodeTexts(rootNode, textList)
        }

        // Também verificar janelas interativas (sub-janelas ou modais)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                for (window in windows) {
                    val wRoot = window.root
                    if (wRoot != null && wRoot != rootNode) {
                        extractNodeTexts(wRoot, textList)
                    }
                }
            } catch (e: Exception) {}
        }

        if (textList.isNotEmpty()) {
            if (!isTripOfferScreen(textList)) {
                return
            }

            parseAndProcessOffer(
                platform = if (isBolt) "BOLT" else "UBER",
                texts = textList
            )
        }
    }

    private fun extractNodeTexts(node: AccessibilityNodeInfo?, list: MutableList<String>) {
        if (node == null) return

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

        for (i in texts.indices) {
            val text = texts[i]

            // 1. Procurar Preços diretamente (ex: 8.50 €, 8,50€, €8.50, 8.50 EUR)
            val priceMatcher = pricePattern.matcher(text)
            while (priceMatcher.find()) {
                val group1 = priceMatcher.group(1)
                val group2 = priceMatcher.group(2)
                val rawVal = (group1 ?: group2)?.replace(',', '.') ?: continue
                rawVal.toDoubleOrNull()?.let { p ->
                    if (p in 1.5..250.0 && !foundPrices.contains(p)) foundPrices.add(p)
                }
            }

            // 2. Procurar Preços quando o símbolo € está no nó anterior ou seguinte
            val prevIsCurrency = i > 0 && (texts[i - 1].trim() == "€" || texts[i - 1].trim().equals("EUR", ignoreCase = true))
            val nextIsCurrency = i < texts.size - 1 && (texts[i + 1].trim() == "€" || texts[i + 1].trim().equals("EUR", ignoreCase = true))
            if (prevIsCurrency || nextIsCurrency) {
                val numMatcher = Pattern.compile("([0-9]+[.,][0-9]{2})").matcher(text)
                while (numMatcher.find()) {
                    val rawVal = numMatcher.group(1)?.replace(',', '.') ?: continue
                    rawVal.toDoubleOrNull()?.let { p ->
                        if (p in 1.5..250.0 && !foundPrices.contains(p)) foundPrices.add(p)
                    }
                }
            }

            // 3. Procurar Distâncias em km (ex: 9.2 km)
            val distMatcher = distKmPattern.matcher(text)
            while (distMatcher.find()) {
                val rawDist = distMatcher.group(1)?.replace(',', '.') ?: continue
                rawDist.toDoubleOrNull()?.let { d ->
                    if (d in 0.1..200.0 && !foundDistances.contains(d)) foundDistances.add(d)
                }
            }

            // 4. Procurar Distâncias em metros (ex: 800 m = 0.8 km)
            val meterMatcher = distMeterPattern.matcher(text)
            while (meterMatcher.find()) {
                val rawMeters = meterMatcher.group(1) ?: continue
                rawMeters.toDoubleOrNull()?.let { m ->
                    val km = m / 1000.0
                    if (km in 0.05..5.0 && !foundDistances.contains(km)) foundDistances.add(km)
                }
            }

            // 5. Procurar Distância quando "km" está no nó seguinte
            val nextIsKm = i < texts.size - 1 && texts[i + 1].trim().equals("km", ignoreCase = true)
            if (nextIsKm) {
                val numMatcher = Pattern.compile("([0-9]+[.,]?[0-9]*)").matcher(text)
                while (numMatcher.find()) {
                    val rawDist = numMatcher.group(1)?.replace(',', '.') ?: continue
                    rawDist.toDoubleOrNull()?.let { d ->
                        if (d in 0.1..200.0 && !foundDistances.contains(d)) foundDistances.add(d)
                    }
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

        val now = System.currentTimeMillis()

        // 1. Se este cartão exato já está a ser mostrado no ecrã neste momento, NÃO re-disparar (deixa o temporizador correr)
        if (OverlayManager.isOverlayVisible &&
            abs(grossFare - OverlayManager.currentGrossFare) < 0.05 &&
            abs(totalDistanceKm - OverlayManager.currentDistanceKm) < 0.2
        ) {
            return
        }

        // 2. Se o motorista acabou de fechar este cartão (✕) há menos de 30 segundos, NÃO reaparecer
        if (abs(grossFare - OverlayManager.lastDismissedGrossFare) < 0.05 &&
            abs(totalDistanceKm - OverlayManager.lastDismissedDistanceKm) < 0.2 &&
            now - OverlayManager.lastDismissedTimestamp < 30000L
        ) {
            return
        }

        // 3. Debounce geral de 5 segundos para a mesma oferta
        if (abs(grossFare - lastGrossFare) < 0.05 &&
            abs(totalDistanceKm - lastDistanceKm) < 0.2 &&
            now - lastOfferTimestamp < 5000L
        ) {
            return
        }

        lastGrossFare = grossFare
        lastDistanceKm = totalDistanceKm
        lastOfferTimestamp = now

        // Read driver preferences from SharedPreferences
        val prefs = getSharedPreferences("VoltDrivePrefs", Context.MODE_PRIVATE)
        val defaultPrefs = getSharedPreferences("voltdrive_prefs", Context.MODE_PRIVATE)
        val platformFeeRate = prefs.getFloat("platformFeeRate", 0.25f).toDouble()
        val energyCostPerKm = prefs.getFloat("energyCostPerKm", 0.0409f).toDouble() // Zoe 18.6 kWh/100km * 0.22€
        val includeVehicleConsumption = defaultPrefs.getBoolean("include_vehicle_consumption", false) ||
                                       prefs.getBoolean("includeVehicleConsumption", false)

        // Profit calculations: se includeVehicleConsumption for false, NÃO calcula/desconta consumo do carro
        val netFare = grossFare * (1.0 - platformFeeRate)
        val electricCost = if (includeVehicleConsumption) (totalDistanceKm * energyCostPerKm) else 0.0
        val netProfit = netFare - electricCost
        val netPerKm = if (totalDistanceKm > 0.0) netProfit / totalDistanceKm else 0.0

        val (verdictText, verdictColor) = when {
            netPerKm >= 0.70 -> Pair("EXCELENTE", Color.parseColor("#00E676")) // Neon Green
            netPerKm >= 0.45 -> Pair("MÍNIMO", Color.parseColor("#FFB020"))     // Amber (>= 0.45 mínimo TVDE)
            else -> Pair("ABAIXO MÍNIMO", Color.parseColor("#FF5252"))         // Alert Red (< 0.45)
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
