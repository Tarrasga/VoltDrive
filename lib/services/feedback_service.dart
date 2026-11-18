import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_suggestion.dart';
import 'buddy_safety_service.dart';
import 'storage_service.dart';
import 'update_service.dart';

class AdminIncomingReport {
  final String id;
  final String title;
  final String description;
  final String category;
  final String author;
  final String vehicleName;
  final String appVersion;
  final String deviceId;
  final DateTime timestamp;
  final int priority;

  AdminIncomingReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.author,
    required this.vehicleName,
    required this.appVersion,
    required this.deviceId,
    required this.timestamp,
    required this.priority,
  });
}

class TelemetryStats {
  final int active24h;
  final int active7d;
  final int totalPings;
  final Map<String, int> carBreakdown;
  final Map<String, int> versionBreakdown;
  final DateTime lastCalculated;

  TelemetryStats({
    required this.active24h,
    required this.active7d,
    required this.totalPings,
    required this.carBreakdown,
    required this.versionBreakdown,
    required this.lastCalculated,
  });
}

class FeedbackService {
  static const String inboxTopic = 'voltdrive-pt-inbox-reports';
  static const String telemetryTopic = 'voltdrive-pt-device-heartbeats';

  static const String _keyAdminMode = 'voltdrive_admin_mode_active';
  static const String _keyLastReadReportTime = 'voltdrive_last_read_report_time';
  static const String _keyLastHeartbeatTime = 'voltdrive_last_heartbeat_time';

  static bool isAdminMode = false;
  static final ValueNotifier<int> unreadAdminReportsCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> incomingReportsNotifier = ValueNotifier<int>(0);

  static List<AdminIncomingReport> cachedIncomingReports = [];
  static TelemetryStats? cachedStats;

  // Cliente HTTP reutilizável com keep-alive para poupar RAM e sockets
  static HttpClient? _sharedHttpClient;
  static HttpClient get _client {
    _sharedHttpClient ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..idleTimeout = const Duration(seconds: 15);
    return _sharedHttpClient!;
  }

  /// Inicialização do serviço (chamado no arranque da app)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isAdminMode = prefs.getBool(_keyAdminMode) ?? false;

      // Executa o heartbeat de telemetria discretamente em segundo plano
      unawaited(sendHeartbeatPing());

      // Se for modo Administrador, verifica relatórios não lidos
      if (isAdminMode) {
        unawaited(checkForNewReports());
      }
    } catch (e) {
      debugPrint('Erro init FeedbackService: $e');
    }
  }

  /// Alternar Modo Administrador / Criador
  static Future<void> setAdminMode(bool enabled) async {
    isAdminMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdminMode, enabled);
    if (enabled) {
      await fetchIncomingReports();
    }
  }

  // ==========================================
  // ENVIO DE SUGESTÕES E BUGS (PELOS CONDUTORES)
  // ==========================================

  /// Envia sugestão ou reporte de bug diretamente pela app (sem precisar de WhatsApp)
  static Future<bool> sendReport({
    required String title,
    required String description,
    required String category,
    String author = '',
  }) async {
    final now = DateTime.now();
    final isBug = category.contains('Erro') || category.contains('Bug');

    final cleanTitle = title.trim().isEmpty ? category : title.trim();
    final cleanDesc = description.trim();
    final cleanAuthor = author.trim().isEmpty ? 'Condutor TVDE' : author.trim();
    final car = BuddySafetyService.vehicleName;
    final devId = BuddySafetyService.myDeviceId;
    final ver = UpdateService.currentVersion;

    final badge = isBug ? '🐛 [Bug]' : (category.contains('Melhoria') ? '⚡ [Melhoria]' : '💡 [Sugestão]');

    final formattedDate = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final messageBody = StringBuffer();
    messageBody.writeln(cleanDesc);
    messageBody.writeln();
    messageBody.writeln('👤 Autor: $cleanAuthor');
    messageBody.writeln('🚗 Veículo: $car');
    messageBody.writeln('📲 VoltDrive v$ver');
    messageBody.writeln('🆔 ID: $devId');
    messageBody.writeln('📅 Data: $formattedDate');

    bool sentOnlineSuccess = false;

    try {
      final url = Uri.parse('https://ntfy.sh');
      final request = await _client.postUrl(url);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'topic': inboxTopic,
        'title': '$badge $cleanTitle',
        'message': messageBody.toString(),
        'priority': isBug ? 4 : 3,
        'tags': isBug ? ['bug', 'warning', 'voltdrive'] : ['bulb', 'sparkles', 'voltdrive'],
        'actions': [
          {
            'action': 'view',
            'label': 'Ver no GitHub',
            'url': 'https://github.com/Tarrasga/VoltDrive',
          }
        ]
      });

      request.write(payload);
      final response = await request.close();
      await response.drain();

      sentOnlineSuccess = (response.statusCode == 200);
    } catch (e) {
      debugPrint('Erro ao enviar reporte online: $e');
      sentOnlineSuccess = false;
    }

    // Guarda sempre localmente no histórico da pasta do condutor
    final suggestion = AppSuggestion(
      id: 'rep-${now.millisecondsSinceEpoch}',
      title: cleanTitle,
      description: cleanDesc,
      category: category,
      author: cleanAuthor,
      createdAt: now,
      sentViaWhatsApp: false,
      sentOnline: sentOnlineSuccess,
      deviceId: devId,
      appVersion: ver,
      vehicleName: car,
    );

    await StorageService.saveAppSuggestion(suggestion);
    return sentOnlineSuccess;
  }

  // ==========================================
  // RECEÇÃO & CAIXA DE ENTRADA (ADMIN / CRIADOR)
  // ==========================================

  /// Consulta os relatórios recebidos nos últimos 30 dias
  static Future<List<AdminIncomingReport>> fetchIncomingReports() async {
    try {
      final url = Uri.parse('https://ntfy.sh/$inboxTopic/json?poll=1&since=30d');
      final request = await _client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) return cachedIncomingReports;

      final body = await response.transform(utf8.decoder).join();
      final lines = body.split('\n');

      final List<AdminIncomingReport> list = [];

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final event = jsonDecode(line);
          if (event['event'] != 'message') continue;

          final id = event['id'] as String? ?? '';
          final rawTitle = event['title'] as String? ?? 'Sugestão sem título';
          final rawMsg = event['message'] as String? ?? '';
          final priority = (event['priority'] as num?)?.toInt() ?? 3;
          final timeSeconds = (event['time'] as num?)?.toInt() ?? 0;
          final dt = timeSeconds > 0
              ? DateTime.fromMillisecondsSinceEpoch(timeSeconds * 1000)
              : DateTime.now();

          // Extrair categoria e título limpo
          String category = '💡 Nova Funcionalidade';
          String title = rawTitle;
          if (rawTitle.contains('[Bug]') || rawTitle.contains('🐛')) {
            category = '🐛 Reportar Erro (Bug)';
            title = rawTitle.replaceAll('🐛', '').replaceAll('[Bug]', '').trim();
          } else if (rawTitle.contains('[Melhoria]') || rawTitle.contains('⚡')) {
            category = '⚡ Melhoria TVDE';
            title = rawTitle.replaceAll('⚡', '').replaceAll('[Melhoria]', '').trim();
          } else {
            category = '💡 Nova Funcionalidade';
            title = rawTitle.replaceAll('💡', '').replaceAll('[Sugestão]', '').trim();
          }

          // Extrair metadados do corpo da mensagem
          String author = '';
          String vehicle = '';
          String version = '';
          String devId = '';
          final descLines = <String>[];

          for (final l in rawMsg.split('\n')) {
            final tl = l.trim();
            if (tl.startsWith('👤 Autor:')) {
              author = tl.replaceAll('👤 Autor:', '').trim();
            } else if (tl.startsWith('🚗 Veículo:')) {
              vehicle = tl.replaceAll('🚗 Veículo:', '').trim();
            } else if (tl.startsWith('📲 VoltDrive v')) {
              version = tl.replaceAll('📲 VoltDrive v', '').trim();
            } else if (tl.startsWith('🆔 ID:')) {
              devId = tl.replaceAll('🆔 ID:', '').trim();
            } else if (tl.startsWith('📅 Data:')) {
              // Ignore
            } else {
              descLines.add(l);
            }
          }

          final desc = descLines.join('\n').trim();

          list.add(AdminIncomingReport(
            id: id,
            title: title.isEmpty ? category : title,
            description: desc,
            category: category,
            author: author.isEmpty ? 'Condutor' : author,
            vehicleName: vehicle.isEmpty ? 'Renault Zoe TVDE' : vehicle,
            appVersion: version.isEmpty ? '1.0' : version,
            deviceId: devId,
            timestamp: dt,
            priority: priority,
          ));
        } catch (_) {}
      }

      // Ordenar decrescente por data
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      cachedIncomingReports = list;

      // Calcular não lidos
      final prefs = await SharedPreferences.getInstance();
      final lastReadMs = prefs.getInt(_keyLastReadReportTime) ?? 0;
      final unread = list.where((r) => r.timestamp.millisecondsSinceEpoch > lastReadMs).length;
      unreadAdminReportsCount.value = unread;
      incomingReportsNotifier.value++;

      return list;
    } catch (e) {
      debugPrint('Erro ao obter relatórios recebidos: $e');
      return cachedIncomingReports;
    }
  }

  /// Verifica se existem novos relatórios não lidos
  static Future<void> checkForNewReports() async {
    await fetchIncomingReports();
  }

  /// Marca todos os relatórios como lidos
  static Future<void> markAllReportsAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastReadReportTime, DateTime.now().millisecondsSinceEpoch);
    unreadAdminReportsCount.value = 0;
  }

  // ==========================================
  // TELEMETRIA DISCRETA (CONTAGEM DE UTILIZADORES)
  // Sem estar escrito nas atualizações
  // ==========================================

  /// Envia um ping silencioso uma vez por dia com dados anónimos de utilização
  static Future<void> sendHeartbeatPing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPing = prefs.getInt(_keyLastHeartbeatTime) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Executa apenas se passaram pelo menos 12 horas desde o último ping
      if (nowMs - lastPing < 12 * 3600 * 1000) return;

      final devId = BuddySafetyService.myDeviceId;
      final ver = UpdateService.currentVersion;
      final car = BuddySafetyService.vehicleName;

      final url = Uri.parse('https://ntfy.sh');
      final request = await _client.postUrl(url);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'topic': telemetryTopic,
        'title': 'hb',
        'message': '$devId|$ver|$car|${DateTime.now().toIso8601String()}',
        'priority': 1,
        'tags': ['stats'],
      });

      request.write(payload);
      final response = await request.close();
      await response.drain();

      if (response.statusCode == 200) {
        await prefs.setInt(_keyLastHeartbeatTime, nowMs);
      }
    } catch (_) {
      // Falhas silenciosas para não incomodar o utilizador nem consumir recursos
    }
  }

  /// Consulta e calcula as estatísticas de utilizadores (Apenas visível no Painel do Criador)
  static Future<TelemetryStats> fetchTelemetryStats() async {
    try {
      final url = Uri.parse('https://ntfy.sh/$telemetryTopic/json?poll=1&since=7d');
      final request = await _client.getUrl(url);
      final response = await request.close();

      final Set<String> devices24h = {};
      final Set<String> devices7d = {};
      final Map<String, int> cars = {};
      final Map<String, int> versions = {};
      int totalPings = 0;

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final lines = body.split('\n');
        final now = DateTime.now();

        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final event = jsonDecode(line);
            if (event['event'] != 'message') continue;

            final rawMsg = event['message'] as String? ?? '';
            final parts = rawMsg.split('|');
            if (parts.length < 3) continue;

            final devId = parts[0].trim();
            final ver = parts[1].trim();
            final car = parts[2].trim();

            final timeSeconds = (event['time'] as num?)?.toInt() ?? 0;
            final dt = timeSeconds > 0
                ? DateTime.fromMillisecondsSinceEpoch(timeSeconds * 1000)
                : now;

            totalPings++;
            devices7d.add(devId);

            if (now.difference(dt).inHours <= 24) {
              devices24h.add(devId);
            }

            if (car.isNotEmpty) {
              cars[car] = (cars[car] ?? 0) + 1;
            }
            if (ver.isNotEmpty) {
              versions[ver] = (versions[ver] ?? 0) + 1;
            }
          } catch (_) {}
        }
      }

      final stats = TelemetryStats(
        active24h: devices24h.length,
        active7d: devices7d.length,
        totalPings: totalPings,
        carBreakdown: cars,
        versionBreakdown: versions,
        lastCalculated: DateTime.now(),
      );

      cachedStats = stats;
      return stats;
    } catch (e) {
      debugPrint('Erro ao obter estatísticas de telemetria: $e');
      return cachedStats ?? TelemetryStats(
        active24h: 0,
        active7d: 0,
        totalPings: 0,
        carBreakdown: {},
        versionBreakdown: {},
        lastCalculated: DateTime.now(),
      );
    }
  }
}
