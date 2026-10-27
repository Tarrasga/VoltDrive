import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/buddy_member.dart';
import 'assistant_service.dart';

class BuddySafetyService {
  static const String _keyTeamCode = 'safety_team_code';
  static const String _keyDriverName = 'safety_driver_name';
  static const String _keyEmergencyPhone = 'safety_emergency_phone';
  static const String _keyDiscreetMode = 'safety_discreet_mode';
  static const String _keySharingActive = 'safety_sharing_active';

  static String teamCode = 'ZOE-PORTUGAL';
  static String driverName = 'Condutor Zoe';
  static String emergencyPhone = '';
  static bool isDiscreetMode = true;
  static bool isSharingActive = true;

  static bool isMySosActive = false;
  static BuddyMember? activeIncomingSos;
  static final List<BuddyMember> colleagues = [];

  static final ValueNotifier<int> updatesNotifier = ValueNotifier<int>(0);
  static Timer? _pollingTimer;

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    teamCode = prefs.getString(_keyTeamCode) ?? 'ZOE-PORTUGAL';
    driverName = prefs.getString(_keyDriverName) ?? 'Condutor Zoe';
    emergencyPhone = prefs.getString(_keyEmergencyPhone) ?? '';
    isDiscreetMode = prefs.getBool(_keyDiscreetMode) ?? true;
    isSharingActive = prefs.getBool(_keySharingActive) ?? true;

    _initDemoColleagues();
    startPolling();
  }

  static Future<void> saveConfig({
    required String newTeamCode,
    required String newDriverName,
    required String newEmergencyPhone,
    required bool newDiscreetMode,
    required bool newSharingActive,
  }) async {
    teamCode = newTeamCode.trim().toUpperCase().replaceAll(' ', '-');
    if (teamCode.isEmpty) teamCode = 'ZOE-PORTUGAL';
    driverName = newDriverName.trim().isEmpty ? 'Condutor Zoe' : newDriverName.trim();
    emergencyPhone = newEmergencyPhone.trim();
    isDiscreetMode = newDiscreetMode;
    isSharingActive = newSharingActive;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTeamCode, teamCode);
    await prefs.setString(_keyDriverName, driverName);
    await prefs.setString(_keyEmergencyPhone, emergencyPhone);
    await prefs.setBool(_keyDiscreetMode, isDiscreetMode);
    await prefs.setBool(_keySharingActive, isSharingActive);

    updatesNotifier.value++;
  }

  static void _initDemoColleagues() {
    if (colleagues.isNotEmpty) return;
    colleagues.addAll([
      BuddyMember(
        id: 'col-1',
        name: 'Manuel P. (Almada)',
        vehicle: 'Renault Zoe Z.E. 50',
        latitude: 38.6780,
        longitude: -9.1620,
        speedKmH: 42.0,
        batteryPercent: 74,
        status: 'A Rodar',
        isSosActive: false,
        sosMessage: '',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      BuddyMember(
        id: 'col-2',
        name: 'Rui M. (Seixal/Corroios)',
        vehicle: 'Renault Zoe R110',
        latitude: 38.6350,
        longitude: -9.1480,
        speedKmH: 0.0,
        batteryPercent: 32,
        status: 'A Carregar 22kW',
        isSosActive: false,
        sosMessage: '',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ]);
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

      final topic = 'voltdrive-team-${teamCode.toLowerCase()}';
      final url = Uri.parse('https://ntfy.sh/$topic');
      final request = await client.postUrl(url);

      request.headers.set('Title', 'Ping VoltDrive: $driverName');
      request.headers.set('Tags', 'voltdrive_ping,car');
      request.headers.set('Priority', 'min');

      final payload = jsonEncode({
        'type': 'ping',
        'id': 'driver-${driverName.hashCode}',
        'name': driverName,
        'lat': loc.latitude,
        'lng': loc.longitude,
        'battery': battery,
        'status': status,
        'speed': loc.speed,
        'time': DateTime.now().toIso8601String(),
      });

      request.write(payload);
      final response = await request.close();
      await response.drain();
    } catch (_) {}
  }

  static Future<bool> sendSosAlert(LocationResult loc, {String? customMessage}) async {
    isMySosActive = true;
    final message = customMessage ?? '🚨 ALERTA SOS: Preciso de apoio imediato!';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final topic = 'voltdrive-team-${teamCode.toLowerCase()}';
      final url = Uri.parse('https://ntfy.sh/$topic');
      final request = await client.postUrl(url);

      final mapsUrl = 'https://maps.google.com/?q=${loc.latitude},${loc.longitude}';

      request.headers.set('Title', '🚨 SOS TVDE: $driverName precisa de apoio!');
      request.headers.set('Priority', 'urgent');
      request.headers.set('Tags', 'warning,rotating_light,sos');
      request.headers.set('Click', mapsUrl);

      final payload = jsonEncode({
        'type': 'sos',
        'id': 'driver-${driverName.hashCode}',
        'name': driverName,
        'lat': loc.latitude,
        'lng': loc.longitude,
        'message': message,
        'mapsUrl': mapsUrl,
        'time': DateTime.now().toIso8601String(),
      });

      request.write(payload);
      final response = await request.close();
      await response.drain();

      updatesNotifier.value++;
      return true;
    } catch (_) {
      updatesNotifier.value++;
      return false;
    }
  }

  static Future<void> cancelMySos() async {
    isMySosActive = false;
    try {
      final client = HttpClient();
      final topic = 'voltdrive-team-${teamCode.toLowerCase()}';
      final request = await client.postUrl(Uri.parse('https://ntfy.sh/$topic'));

      request.headers.set('Title', '✅ SOS Resolvido: $driverName está em segurança');
      request.headers.set('Priority', 'default');
      request.headers.set('Tags', 'white_check_mark');
      request.write(jsonEncode({'type': 'sos_cancel', 'name': driverName}));
      final response = await request.close();
      await response.drain();
    } catch (_) {}
    updatesNotifier.value++;
  }

  static Future<void> pollTeamUpdates() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final topic = 'voltdrive-team-${teamCode.toLowerCase()}';
      final url = Uri.parse('https://ntfy.sh/$topic/json?poll=1&since=5m');

      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) return;

      final body = await response.transform(utf8.decoder).join();
      final lines = body.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final event = jsonDecode(line);
          final msgText = event['message'] as String? ?? '';
          if (msgText.startsWith('{') && msgText.endsWith('}')) {
            final data = jsonDecode(msgText);
            final type = data['type'] as String? ?? '';
            final senderName = data['name'] as String? ?? '';

            if (senderName == driverName) continue; // Ignorar próprio

            if (type == 'sos') {
              activeIncomingSos = BuddyMember(
                id: data['id'] as String? ?? 'sos-${DateTime.now().millisecondsSinceEpoch}',
                name: senderName,
                vehicle: 'Renault Zoe TVDE',
                latitude: (data['lat'] as num?)?.toDouble() ?? 38.65,
                longitude: (data['lng'] as num?)?.toDouble() ?? -9.15,
                speedKmH: 0.0,
                batteryPercent: 50,
                status: '🚨 SOS ATIVO',
                isSosActive: true,
                sosMessage: data['message'] as String? ?? 'Preciso de apoio!',
                updatedAt: DateTime.now(),
              );
              updatesNotifier.value++;
            } else if (type == 'sos_cancel') {
              if (activeIncomingSos?.name == senderName) {
                activeIncomingSos = null;
                updatesNotifier.value++;
              }
            } else if (type == 'ping') {
              final idx = colleagues.indexWhere((c) => c.name == senderName);
              final updated = BuddyMember.fromJson(data);
              if (idx >= 0) {
                colleagues[idx] = updated;
              } else {
                colleagues.add(updated);
              }
              updatesNotifier.value++;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static void simulateIncomingSosFromColleague() {
    activeIncomingSos = BuddyMember(
      id: 'demo-sos',
      name: 'Manuel P. (Almada)',
      vehicle: 'Renault Zoe Z.E. 50',
      latitude: 38.6790,
      longitude: -9.1640,
      speedKmH: 0.0,
      batteryPercent: 62,
      status: '🚨 SOS ATIVO',
      isSosActive: true,
      sosMessage: '🚨 SOS! Tive um problema com um passageiro e preciso de apoio perto do Fórum Almada!',
      updatedAt: DateTime.now(),
    );
    updatesNotifier.value++;
  }

  static void dismissIncomingSos() {
    activeIncomingSos = null;
    updatesNotifier.value++;
  }
}
