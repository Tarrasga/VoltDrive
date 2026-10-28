import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_shift.dart';
import '../models/financial_goals.dart';
import '../models/vehicle_profile.dart';
import 'storage_service.dart';

class CloudSyncService {
  static const String defaultSupabaseUrl = 'https://rkgegwmsqipabtqxkmqa.supabase.co';
  static const String defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrZ2Vnd21zcWlwYWJ0cXhrbXFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxODc4MzYsImV4cCI6MjEwODc2MzgzNn0.GK3QmZqPHGmkIysUNv2V192JIbS2SvkMHHmUYEhmQes';

  static const String _keySupabaseUrl = 'voltdrive_cloud_supabase_url';
  static const String _keySupabaseAnonKey = 'voltdrive_cloud_supabase_anon_key';
  static const String _keyAccessToken = 'voltdrive_cloud_access_token';
  static const String _keyRefreshToken = 'voltdrive_cloud_refresh_token';
  static const String _keyUserId = 'voltdrive_cloud_user_id';
  static const String _keyUserEmail = 'voltdrive_cloud_user_email';
  static const String _keyLastSyncTime = 'voltdrive_cloud_last_sync_time';

  static String _supabaseUrl = defaultSupabaseUrl;
  static String _anonKey = defaultAnonKey;
  static String _accessToken = '';
  static String _refreshToken = '';
  static String _userId = '';
  static String _userEmail = '';
  static DateTime? _lastSyncTime;

  static ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  static ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);

  static bool get isConfigured => _supabaseUrl.isNotEmpty && _anonKey.isNotEmpty;
  static bool get isLoggedIn => _accessToken.isNotEmpty && _userId.isNotEmpty;
  static String get userEmail => _userEmail;
  static DateTime? get lastSyncTime => _lastSyncTime;

  /// Inicializa o serviço carregando credenciais e tokens guardados
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _supabaseUrl = prefs.getString(_keySupabaseUrl) ?? defaultSupabaseUrl;
      if (_supabaseUrl.isEmpty) _supabaseUrl = defaultSupabaseUrl;
      _anonKey = prefs.getString(_keySupabaseAnonKey) ?? defaultAnonKey;
      if (_anonKey.isEmpty) _anonKey = defaultAnonKey;

      _accessToken = prefs.getString(_keyAccessToken) ?? '';
      _refreshToken = prefs.getString(_keyRefreshToken) ?? '';
      _userId = prefs.getString(_keyUserId) ?? '';
      _userEmail = prefs.getString(_keyUserEmail) ?? '';

      final lastSyncStr = prefs.getString(_keyLastSyncTime);
      if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
        _lastSyncTime = DateTime.tryParse(lastSyncStr);
      }

      isLoggedInNotifier.value = isLoggedIn;
    } catch (e) {
      debugPrint('Erro ao inicializar CloudSyncService: $e');
    }
  }

  /// Configura o URL e a Chave pública (anon) do Supabase
  static Future<void> configure({required String url, required String anonKey}) async {
    _supabaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _anonKey = anonKey.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySupabaseUrl, _supabaseUrl);
    await prefs.setString(_keySupabaseAnonKey, _anonKey);
  }

  // ==========================================
  // AUTENTICAÇÃO (REGISTO & LOGIN)
  // ==========================================

  /// Registar nova conta na nuvem com Email e Palavra-passe
  static Future<bool> register({required String email, required String password}) async {
    if (!isConfigured) throw Exception('Servidor cloud não configurado.');

    final endpoint = Uri.parse('$_supabaseUrl/auth/v1/signup');
    final response = await _postJson(endpoint, {
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
    });

    if (response['access_token'] != null) {
      await _saveAuthSession(response);
      return true;
    }

    if (response['user'] != null && response['user']['id'] != null) {
      // Registo com confirmação de email pendente ou criado
      return await login(email: email, password: password);
    }

    final msg = response['msg'] ?? response['error_description'] ?? response['message'] ?? 'Erro no registo.';
    throw Exception(msg);
  }

  /// Iniciar sessão com Email e Palavra-passe
  static Future<bool> login({required String email, required String password}) async {
    if (!isConfigured) throw Exception('Servidor cloud não configurado.');

    final endpoint = Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=password');
    final response = await _postJson(endpoint, {
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
    });

    if (response['access_token'] != null) {
      await _saveAuthSession(response);
      // Ao fazer login, descarrega imediatamente os dados do utilizador
      await pullAllFromCloud();
      return true;
    }

    final msg = response['error_description'] ?? response['msg'] ?? response['message'] ?? 'Email ou palavra-passe incorretos.';
    throw Exception(msg);
  }

  /// Terminar sessão
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = '';
    _refreshToken = '';
    _userId = '';
    _userEmail = '';

    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);

    isLoggedInNotifier.value = false;
  }

  static Future<void> _saveAuthSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = data['access_token'] as String? ?? '';
    _refreshToken = data['refresh_token'] as String? ?? '';
    final user = data['user'] as Map<String, dynamic>? ?? {};
    _userId = user['id'] as String? ?? '';
    _userEmail = user['email'] as String? ?? '';

    await prefs.setString(_keyAccessToken, _accessToken);
    await prefs.setString(_keyRefreshToken, _refreshToken);
    await prefs.setString(_keyUserId, _userId);
    await prefs.setString(_keyUserEmail, _userEmail);

    isLoggedInNotifier.value = isLoggedIn;
  }

  // ==========================================
  // SINCRONIZAÇÃO DE DADOS (PULL & PUSH)
  // ==========================================

  /// Envia todos os dados locais (turnos, metas, veículo) para a nuvem
  static Future<void> syncAllToCloud() async {
    if (!isLoggedIn) return;

    try {
      isSyncingNotifier.value = true;

      // 1. Enviar perfil do veículo
      final profile = await StorageService.loadVehicleProfile();
      await _upsertRow('vehicle_profiles', {
        'user_id': _userId,
        'name': profile.name,
        'battery_capacity_kwh': profile.batteryCapacityKwh,
        'avg_consumption_kwh_100': profile.avgConsumptionKwh100,
        'home_kwh_price': profile.homeKwhPrice,
        'public_kwh_price': profile.publicKwhPrice,
        'target_daily_profit': profile.targetDailyProfit,
      }, 'user_id');

      // 2. Enviar metas financeiras
      final goals = await StorageService.loadFinancialGoals();
      await _upsertRow('financial_goals', {
        'user_id': _userId,
        'monthly_target': goals.monthlyTarget,
        'weekly_target': goals.weeklyTarget,
        'target_type': goals.targetType,
        'work_days_per_week': goals.workDaysPerWeek,
      }, 'user_id');

      // 3. Enviar todos os turnos
      final shifts = await StorageService.loadShifts();
      if (shifts.isNotEmpty) {
        final shiftsPayload = shifts.map((s) => {
          'id': s.id,
          'user_id': _userId,
          'date': s.date.toIso8601String(),
          'driver_earnings': s.driverEarnings,
          'tips': s.tips,
          'start_km': s.startKm,
          'end_km': s.endKm,
          'total_km': s.totalKm,
          'hours_worked': s.hoursWorked,
          'charging_cost': s.chargingCost,
          'charging_kwh': s.chargingKwh,
          'tolls_cost': s.tollsCost,
          'other_expenses': s.otherExpenses,
          'net_profit': s.netProfit,
          'notes': s.notes,
        }).toList();

        await _upsertBatch('shifts', shiftsPayload, 'id');
      }

      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSyncTime, _lastSyncTime!.toIso8601String());
    } catch (e) {
      debugPrint('Erro ao sincronizar com a cloud: $e');
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Descarrega todos os dados da nuvem para o telemóvel
  static Future<void> pullAllFromCloud() async {
    if (!isLoggedIn) return;

    try {
      isSyncingNotifier.value = true;

      // 1. Obter perfil do veículo
      final profileRows = await _getRows('vehicle_profiles?user_id=eq.$_userId');
      if (profileRows.isNotEmpty) {
        final r = profileRows.first;
        final profile = VehicleProfile(
          name: r['name'] as String? ?? 'Renault Zoe Z.E. 50',
          batteryCapacityKwh: (r['battery_capacity_kwh'] as num?)?.toDouble() ?? 52.0,
          avgConsumptionKwh100: (r['avg_consumption_kwh_100'] as num?)?.toDouble() ?? 18.6,
          homeKwhPrice: (r['home_kwh_price'] as num?)?.toDouble() ?? 0.16,
          publicKwhPrice: (r['public_kwh_price'] as num?)?.toDouble() ?? 0.32,
          targetDailyProfit: (r['target_daily_profit'] as num?)?.toDouble() ?? 120.0,
        );
        await StorageService.saveVehicleProfile(profile);
      }

      // 2. Obter metas
      final goalRows = await _getRows('financial_goals?user_id=eq.$_userId');
      if (goalRows.isNotEmpty) {
        final g = goalRows.first;
        final goals = FinancialGoals(
          monthlyTarget: (g['monthly_target'] as num?)?.toDouble() ?? 2500.0,
          weeklyTarget: (g['weekly_target'] as num?)?.toDouble() ?? 600.0,
          targetType: g['target_type'] as String? ?? 'monthly',
          workDaysPerWeek: g['work_days_per_week'] as int? ?? 6,
        );
        await StorageService.saveFinancialGoals(goals);
      }

      // 3. Obter turnos
      final shiftRows = await _getRows('shifts?user_id=eq.$_userId&order=date.desc');
      for (final s in shiftRows) {
        final shift = DailyShift(
          id: s['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.tryParse(s['date'] as String? ?? '') ?? DateTime.now(),
          driverEarnings: (s['driver_earnings'] as num?)?.toDouble() ?? 0.0,
          tips: (s['tips'] as num?)?.toDouble() ?? 0.0,
          startKm: (s['start_km'] as num?)?.toDouble() ?? 0.0,
          endKm: (s['end_km'] as num?)?.toDouble() ?? 0.0,
          totalKm: (s['total_km'] as num?)?.toDouble() ?? 0.0,
          hoursWorked: (s['hours_worked'] as num?)?.toDouble() ?? 0.0,
          chargingCost: (s['charging_cost'] as num?)?.toDouble() ?? 0.0,
          chargingKwh: (s['charging_kwh'] as num?)?.toDouble() ?? 0.0,
          tollsCost: (s['tolls_cost'] as num?)?.toDouble() ?? 0.0,
          otherExpenses: (s['other_expenses'] as num?)?.toDouble() ?? 0.0,
          notes: s['notes'] as String? ?? '',
        );
        await StorageService.saveShift(shift);
      }

      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSyncTime, _lastSyncTime!.toIso8601String());
    } catch (e) {
      debugPrint('Erro ao descarregar da cloud: $e');
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  // ==========================================
  // HELPERS REST HTTP NATIVOS
  // ==========================================

  static Map<String, String> get _headers => {
    'apikey': _anonKey,
    'Authorization': 'Bearer ${_accessToken.isNotEmpty ? _accessToken : _anonKey}',
    'Content-Type': 'application/json',
    'Prefer': 'return=minimal',
  };

  static Future<Map<String, dynamic>> _postJson(Uri url, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      _headers.forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (responseBody.isEmpty) return {};
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static Future<void> _upsertRow(String table, Map<String, dynamic> data, String onConflict) async {
    final client = HttpClient();
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/$table?on_conflict=$onConflict');
      final request = await client.postUrl(url);
      _headers.forEach((k, v) => request.headers.set(k, v));
      request.headers.set('Prefer', 'resolution=merge-duplicates');
      request.write(jsonEncode(data));
      final response = await request.close();
      await response.drain();
    } finally {
      client.close();
    }
  }

  static Future<void> _upsertBatch(String table, List<Map<String, dynamic>> data, String onConflict) async {
    final client = HttpClient();
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/$table?on_conflict=$onConflict');
      final request = await client.postUrl(url);
      _headers.forEach((k, v) => request.headers.set(k, v));
      request.headers.set('Prefer', 'resolution=merge-duplicates');
      request.write(jsonEncode(data));
      final response = await request.close();
      await response.drain();
    } finally {
      client.close();
    }
  }

  static Future<List<Map<String, dynamic>>> _getRows(String query) async {
    final client = HttpClient();
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/$query');
      final request = await client.getUrl(url);
      _headers.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (responseBody.isEmpty) return [];
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } finally {
      client.close();
    }
  }
}
