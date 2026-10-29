import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/buddy_member.dart';
import '../models/emergency_contact.dart';
import 'assistant_service.dart';

class BuddySafetyService {
  static const String _keyTeamCode = 'safety_team_code';
  static const String _keyTeamPassword = 'safety_team_password';
  static const String _keyDriverName = 'safety_driver_name';
  static const String _keyEmergencyPhone = 'safety_emergency_phone';
  static const String _keyEmergencyContacts = 'safety_emergency_contacts';
  static const String _keyDiscreetMode = 'safety_discreet_mode';
  static const String _keySharingActive = 'safety_sharing_active';

  static String teamCode = 'ZOE-PORTUGAL';
  static String teamPassword = '';
  static String driverName = 'Condutor Zoe';
  static String emergencyPhone = '';
  static bool isDiscreetMode = true;
  static bool isSharingActive = true;

  // Canal seguro derivado com nome e palavra-passe
  static String get effectiveChannelTopic {
    final cleanCode = teamCode.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
    final cleanPass = teamPassword.trim();
    if (cleanPass.isEmpty) {
      return 'voltdrive-team-$cleanCode';
    }
    // Com palavra-passe: deriva um hash único sha256 de 12 caracteres (isolamento total)
    final hash = sha256.convert(utf8.encode('${cleanCode}_$cleanPass')).toString().substring(0, 12);
    return 'voltdrive-sec-$cleanCode-$hash';
  }

  static bool isMySosActive = false;
  static BuddyMember? activeIncomingSos;
  // Colegas reais da equipa (SEM BOTS)
  static final List<BuddyMember> colleagues = [];
  // Lista de contactos rápidos de emergência
  static final List<EmergencyContact> emergencyContacts = [];

  static final ValueNotifier<int> updatesNotifier = ValueNotifier<int>(0);
  static Timer? _pollingTimer;

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    teamCode = prefs.getString(_keyTeamCode) ?? 'ZOE-PORTUGAL';
    teamPassword = prefs.getString(_keyTeamPassword) ?? '';
    driverName = prefs.getString(_keyDriverName) ?? 'Condutor Zoe';
    emergencyPhone = prefs.getString(_keyEmergencyPhone) ?? '';
    isDiscreetMode = prefs.getBool(_keyDiscreetMode) ?? true;
    isSharingActive = prefs.getBool(_keySharingActive) ?? true;

    // Carregar contactos de emergência
    emergencyContacts.clear();
    final contactsJson = prefs.getString(_keyEmergencyContacts);
    if (contactsJson != null && contactsJson.isNotEmpty) {
      try {
        final List list = jsonDecode(contactsJson);
        emergencyContacts.addAll(list.map((e) => EmergencyContact.fromJson(e)));
      } catch (_) {}
    }

    // Se tiver número antigo mas lista vazia, adicionar como contacto padrão
    if (emergencyContacts.isEmpty && emergencyPhone.isNotEmpty) {
      emergencyContacts.add(EmergencyContact(
        id: 'default-1',
        name: 'Colega TVDE',
        phone: emergencyPhone,
      ));
    }

    // Garantir que a lista de colegas começa limpa (sem bots)
    colleagues.clear();

    startPolling();
  }

  static Future<void> saveConfig({
    required String newTeamCode,
    String newTeamPassword = '',
    required String newDriverName,
    required String newEmergencyPhone,
    required bool newDiscreetMode,
    required bool newSharingActive,
  }) async {
    teamCode = newTeamCode.trim().toUpperCase().replaceAll(' ', '-');
    if (teamCode.isEmpty) teamCode = 'ZOE-PORTUGAL';
    teamPassword = newTeamPassword.trim();
    driverName = newDriverName.trim().isEmpty ? 'Condutor Zoe' : newDriverName.trim();
    emergencyPhone = newEmergencyPhone.trim();
    isDiscreetMode = newDiscreetMode;
    isSharingActive = newSharingActive;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTeamCode, teamCode);
    await prefs.setString(_keyTeamPassword, teamPassword);
    await prefs.setString(_keyDriverName, driverName);
    await prefs.setString(_keyEmergencyPhone, emergencyPhone);
    await prefs.setBool(_keyDiscreetMode, isDiscreetMode);
    await prefs.setBool(_keySharingActive, isSharingActive);

    colleagues.clear();
    updatesNotifier.value++;
    startPolling();
  }

  static Future<void> addEmergencyContact(String name, String phone) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final cleanName = name.trim().isEmpty ? 'Contacto' : name.trim();
    if (cleanPhone.isEmpty) return;

    emergencyContacts.add(EmergencyContact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: cleanName,
      phone: cleanPhone,
    ));

    await _saveContactsToPrefs();
  }

  static Future<void> removeEmergencyContact(String id) async {
    emergencyContacts.removeWhere((c) => c.id == id);
    await _saveContactsToPrefs();
  }

  static Future<void> _saveContactsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(emergencyContacts.map((c) => c.toJson()).toList());
    await prefs.setString(_keyEmergencyContacts, jsonStr);
    if (emergencyContacts.isNotEmpty) {
      emergencyPhone = emergencyContacts.first.phone;
      await prefs.setString(_keyEmergencyPhone, emergencyPhone);
    }
    updatesNotifier.value++;
  }

  static void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      pollTeamUpdates();
    });
    pollTeamUpdates();
  }

  static Future<void> broadcastMyLocation(LocationResult loc, {int battery = 80, String status = 'A Rodar'}) async {
    if (!isSharingActive) return;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      final topic = effectiveChannelTopic;
      final url = Uri.parse('https://ntfy.sh');
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'topic': topic,
        'title': 'Ping: $driverName',
        'message': jsonEncode({
          'type': 'ping',
          'id': 'driver-${driverName.hashCode}',
          'name': driverName,
          'has_pass': teamPassword.isNotEmpty,
          'lat': loc.latitude,
          'lng': loc.longitude,
          'battery': battery,
          'status': status,
          'speed': loc.speed,
          'time': DateTime.now().toIso8601String(),
        }),
        'priority': 1,
        'tags': ['voltdrive_ping', 'car'],
      });

      request.write(payload);
      final response = await request.close();
      await response.drain();
    } catch (_) {}
  }

  static Future<bool> sendSosAlert(LocationResult loc, {String? customMessage}) async {
    isMySosActive = true;
    final message = customMessage ?? '🚨 ALERTA SOS: Preciso de apoio imediato!';
    final mapsUrl = 'https://maps.google.com/?q=${loc.latitude},${loc.longitude}';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final topic = effectiveChannelTopic;
      final url = Uri.parse('https://ntfy.sh');
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'topic': topic,
        'title': '🚨 SOS TVDE: $driverName precisa de apoio!',
        'message': '$message\n📍 Coordenadas: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}\n🗺️ Ver no Mapa: $mapsUrl',
        'priority': 5,
        'tags': ['warning', 'rotating_light', 'sos'],
        'click': mapsUrl,
        'actions': [
          {
            'action': 'view',
            'label': 'Abrir no Google Maps',
            'url': mapsUrl,
          }
        ]
      });

      request.write(payload);
      final response = await request.close();
      await response.drain();

      updatesNotifier.value++;
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending SOS: $e');
      updatesNotifier.value++;
      return false;
    }
  }

  static Future<void> cancelMySos() async {
    isMySosActive = false;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final topic = effectiveChannelTopic;
      final url = Uri.parse('https://ntfy.sh');
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'topic': topic,
        'title': '✅ SOS Resolvido: $driverName em seguranca',
        'message': 'O condutor $driverName ja se encontra em seguranca.',
        'priority': 3,
        'tags': ['white_check_mark', 'sos_cancel'],
      });

      request.write(payload);
      final response = await request.close();
      await response.drain();
    } catch (_) {}
    updatesNotifier.value++;
  }

  static Future<void> pollTeamUpdates() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final topic = effectiveChannelTopic;
      final url = Uri.parse('https://ntfy.sh/$topic/json?poll=1&since=10m');

      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) return;

      final body = await response.transform(utf8.decoder).join();
      final lines = body.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final event = jsonDecode(line);
          final eventType = event['event'] as String? ?? '';
          if (eventType != 'message') continue;

          final title = event['title'] as String? ?? '';
          final msgText = event['message'] as String? ?? '';
          final tags = (event['tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
          final priority = (event['priority'] as num?)?.toInt() ?? 3;
          final clickUrl = event['click'] as String? ?? '';

          // 1. Cancelamento de SOS
          if (tags.contains('sos_cancel') || title.contains('SOS Resolvido')) {
            activeIncomingSos = null;
            updatesNotifier.value++;
            continue;
          }

          // 2. Alerta de SOS recebido de colega
          if (tags.contains('sos') || priority >= 5 || title.contains('SOS')) {
            String sender = 'Colega TVDE';
            if (title.contains(':')) {
              final parts = title.split(':');
              if (parts.length > 1) {
                sender = parts[1].replaceAll('precisa de apoio!', '').replaceAll('🚨', '').trim();
              }
            }

            if (sender == driverName) continue; // Ignorar próprio alerta

            double lat = 38.6500;
            double lng = -9.1500;
            if (clickUrl.contains('?q=')) {
              final coordsStr = clickUrl.split('?q=')[1];
              final parts = coordsStr.split(',');
              if (parts.length >= 2) {
                lat = double.tryParse(parts[0]) ?? lat;
                lng = double.tryParse(parts[1]) ?? lng;
              }
            }

            activeIncomingSos = BuddyMember(
              id: event['id'] as String? ?? 'sos-${DateTime.now().millisecondsSinceEpoch}',
              name: sender,
              vehicle: 'Renault Zoe TVDE',
              latitude: lat,
              longitude: lng,
              speedKmH: 0.0,
              batteryPercent: 50,
              status: '🚨 SOS ATIVO',
              isSosActive: true,
              sosMessage: msgText,
              updatedAt: DateTime.now(),
            );
            updatesNotifier.value++;
            continue;
          }

          // 3. Ping de localização de colega real
          if (tags.contains('voltdrive_ping') || msgText.contains('"type":"ping"')) {
            try {
              final pingData = jsonDecode(msgText);
              final sender = pingData['name'] as String? ?? '';
              if (sender.isNotEmpty && sender != driverName) {
                final idx = colleagues.indexWhere((c) => c.name == sender);
                final updated = BuddyMember.fromJson(pingData);
                if (idx >= 0) {
                  colleagues[idx] = updated;
                } else {
                  colleagues.add(updated);
                }
                updatesNotifier.value++;
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static void dismissIncomingSos() {
    activeIncomingSos = null;
    updatesNotifier.value++;
  }
}
