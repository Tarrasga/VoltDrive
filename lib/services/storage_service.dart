import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle_profile.dart';
import '../models/daily_shift.dart';
import '../models/driving_session.dart';

class StorageService {
  static const String _keyVehicleProfile = 'voltdrive_vehicle_profile';
  static const String _keyShifts = 'voltdrive_shifts';
  static const String _keyCurrentDrivingSession = 'voltdrive_current_driving_session';
  static const String _keyDrivingHistory = 'voltdrive_driving_history';

  // Carregar perfil do veículo
  static Future<VehicleProfile> loadVehicleProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyVehicleProfile);
      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonString);
        return VehicleProfile.fromJson(map);
      }
    } catch (e) {
      // Se houver erro, devolve o padrão
    }
    return VehicleProfile();
  }

  // Guardar perfil do veículo
  static Future<bool> saveVehicleProfile(VehicleProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(profile.toJson());
    return await prefs.setString(_keyVehicleProfile, jsonString);
  }

  // Carregar todos os turnos diários financeiros
  static Future<List<DailyShift>> loadShifts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyShifts);
      if (listJson != null) {
        return listJson
            .map((item) => DailyShift.fromJson(jsonDecode(item)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)); // Mais recentes primeiro
      }
    } catch (e) {
      // Erro ao carregar
    }
    return [];
  }

  // Guardar ou atualizar um turno
  static Future<void> saveShift(DailyShift shift) async {
    final prefs = await SharedPreferences.getInstance();
    final shifts = await loadShifts();
    
    final existingIndex = shifts.indexWhere((s) => s.id == shift.id);
    if (existingIndex >= 0) {
      shifts[existingIndex] = shift;
    } else {
      shifts.insert(0, shift);
    }

    final listJson = shifts.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyShifts, listJson);
  }

  // Apagar um turno
  static Future<void> deleteShift(String shiftId) async {
    final prefs = await SharedPreferences.getInstance();
    final shifts = await loadShifts();
    shifts.removeWhere((s) => s.id == shiftId);
    final listJson = shifts.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyShifts, listJson);
  }

  // ==========================================
  // REGISTO DE HORAS DE CONDUÇÃO (LEI TVDE)
  // ==========================================

  // Carregar sessão de condução ativa do dia
  static Future<DrivingShiftSession> loadCurrentDrivingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyCurrentDrivingSession);
      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonString);
        final session = DrivingShiftSession.fromJson(map);
        // Se a sessão for de um dia anterior, cria uma nova
        final now = DateTime.now();
        if (session.date.year == now.year && session.date.month == now.month && session.date.day == now.day) {
          return session;
        }
      }
    } catch (e) {
      // Ignora erro e cria nova
    }
    return DrivingShiftSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
    );
  }

  // Guardar sessão atual de condução
  static Future<void> saveCurrentDrivingSession(DrivingShiftSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(session.toJson());
    await prefs.setString(_keyCurrentDrivingSession, jsonString);
  }

  // Arquivar sessão de condução no histórico diário
  static Future<void> archiveDrivingSession(DrivingShiftSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList(_keyDrivingHistory) ?? [];
    listJson.insert(0, jsonEncode(session.toJson()));
    await prefs.setStringList(_keyDrivingHistory, listJson);
  }

  // Carregar histórico de sessões de condução
  static Future<List<DrivingShiftSession>> loadDrivingHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyDrivingHistory);
      if (listJson != null) {
        return listJson
            .map((item) => DrivingShiftSession.fromJson(jsonDecode(item)))
            .toList();
      }
    } catch (e) {
      // Erro ao carregar
    }
    return [];
  }
}
