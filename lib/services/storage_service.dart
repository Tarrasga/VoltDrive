import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle_profile.dart';
import '../models/daily_shift.dart';
import '../models/driving_session.dart';
import '../models/financial_goals.dart';
import '../models/monthly_expense.dart';
import '../models/app_suggestion.dart';
import 'cloud_sync_service.dart';
import 'update_service.dart';

class StorageService {
  static const String _keyVehicleProfile = 'voltdrive_vehicle_profile';
  static const String _keyShifts = 'voltdrive_shifts';
  static const String _keyFinancialGoals = 'voltdrive_financial_goals';
  static const String _keyCurrentDrivingSession = 'voltdrive_current_driving_session';
  static const String _keyDrivingHistory = 'voltdrive_driving_history';
  static const String _keyMonthlyExpenses = 'voltdrive_monthly_expenses';
  static const String _keyAppSuggestions = 'voltdrive_app_suggestions';

  // ==========================================
  // DESPESAS MENSAIS (BATERIAS, VIA VERDE, PNEUS)
  // ==========================================

  /// Carrega todas as despesas mensais gravadas
  static Future<List<MonthlyExpense>> loadMonthlyExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyMonthlyExpenses);
      if (listJson != null && listJson.isNotEmpty) {
        return listJson.map((item) => MonthlyExpense.fromJson(jsonDecode(item))).toList();
      }
    } catch (_) {}

    // Padrões iniciais para motoristas TVDE (Zoe Edition)
    return [
      MonthlyExpense(
        id: 'default_battery',
        monthKey: '',
        title: 'Baterias (Aluguer Zoe)',
        amount: 0.0,
        isRecurring: true,
        category: 'battery',
      ),
      MonthlyExpense(
        id: 'default_via_verde',
        monthKey: '',
        title: 'Via Verde / Portagens',
        amount: 0.0,
        isRecurring: true,
        category: 'tolls',
      ),
    ];
  }

  /// Guarda a lista global de despesas mensais
  static Future<void> saveMonthlyExpenses(List<MonthlyExpense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = expenses.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyMonthlyExpenses, listJson);
    if (CloudSyncService.isLoggedIn) {
      CloudSyncService.syncAllToCloud();
    }
  }

  /// Devolve as despesas aplicáveis para um determinado mês (ex: 2026, 11)
  static Future<List<MonthlyExpense>> getExpensesForMonth(int year, int month) async {
    final all = await loadMonthlyExpenses();
    final targetMonthKey = '$year-${month.toString().padLeft(2, '0')}';

    final Map<String, MonthlyExpense> effectiveExpenses = {};

    // 1. Aplicar despesas recorrentes base
    for (final exp in all.where((e) => e.isRecurring && e.monthKey.isEmpty)) {
      effectiveExpenses[exp.title.toLowerCase().trim()] = exp;
    }

    // 2. Aplicar despesas específicas deste mês (podem sobrescrever ou ser novas)
    for (final exp in all.where((e) => e.monthKey == targetMonthKey)) {
      effectiveExpenses[exp.title.toLowerCase().trim()] = exp;
    }

    final list = effectiveExpenses.values.toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  /// Adiciona ou atualiza uma despesa para um mês específico
  static Future<void> saveExpenseForMonth(MonthlyExpense expense) async {
    final all = await loadMonthlyExpenses();
    final index = all.indexWhere((e) => e.id == expense.id);
    if (index >= 0) {
      all[index] = expense;
    } else {
      all.add(expense);
    }
    await saveMonthlyExpenses(all);
  }

  /// Remove uma despesa mensal
  static Future<void> deleteMonthlyExpense(String id) async {
    final all = await loadMonthlyExpenses();
    all.removeWhere((e) => e.id == id);
    await saveMonthlyExpenses(all);
  }

  // Carregar metas financeiras
  static Future<FinancialGoals> loadFinancialGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyFinancialGoals);
      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonString);
        return FinancialGoals.fromJson(map);
      }
    } catch (_) {}
    return FinancialGoals();
  }

  // Guardar metas financeiras
  static Future<bool> saveFinancialGoals(FinancialGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(goals.toJson());
    final res = await prefs.setString(_keyFinancialGoals, jsonString);
    if (CloudSyncService.isLoggedIn) {
      CloudSyncService.syncAllToCloud();
    }
    return res;
  }

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
    final res = await prefs.setString(_keyVehicleProfile, jsonString);
    if (CloudSyncService.isLoggedIn) {
      CloudSyncService.syncAllToCloud();
    }
    return res;
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

    if (CloudSyncService.isLoggedIn) {
      CloudSyncService.syncAllToCloud();
    }
  }

  // Apagar um turno
  static Future<void> deleteShift(String shiftId) async {
    final prefs = await SharedPreferences.getInstance();
    final shifts = await loadShifts();
    shifts.removeWhere((s) => s.id == shiftId);
    final listJson = shifts.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyShifts, listJson);

    if (CloudSyncService.isLoggedIn) {
      CloudSyncService.syncAllToCloud();
    }
  }

  // Obter turnos de um determinado mês
  static Future<List<DailyShift>> getShiftsForMonth(DateTime month) async {
    final all = await loadShifts();
    return all.where((s) => s.date.year == month.year && s.date.month == month.month).toList();
  }

  // Obter turnos de uma determinada semana
  static Future<List<DailyShift>> getShiftsForWeek(DateTime dateInWeek) async {
    final all = await loadShifts();
    final monday = dateInWeek.subtract(Duration(days: dateInWeek.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 7));
    return all.where((s) => s.date.isAfter(start.subtract(const Duration(seconds: 1))) && s.date.isBefore(end)).toList();
  }

  // Obter turno de um dia específico
  static Future<DailyShift?> getShiftForDate(DateTime date) async {
    final all = await loadShifts();
    try {
      return all.firstWhere((s) => s.date.year == date.year && s.date.month == date.month && s.date.day == date.day);
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // REGISTO DE HORAS DE CONDUÇÃO (LEI TVDE)
  // ==========================================

  // Carregar sessão de condução ativa do dia (ou turno que cruzou a meia-noite)
  static Future<DrivingShiftSession> loadCurrentDrivingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyCurrentDrivingSession);
      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonString);
        final session = DrivingShiftSession.fromJson(map);
        final now = DateTime.now();

        // 1. Se o turno ainda estiver em curso (conduzindo ou em pausa), mantê-lo ativo mesmo após a meia-noite!
        if (session.currentState != DrivingState.parado) {
          final lastActivity = session.lastStateChangeTime ?? session.shiftStartTime ?? session.date;
          // Se passou mais de 24 horas sem qualquer sinal, encerra e arquiva por segurança
          if (now.difference(lastActivity).inHours >= 24) {
            session.syncWithClock();
            session.currentState = DrivingState.parado;
            session.shiftEndTime ??= lastActivity.add(const Duration(hours: 10));
            await archiveDrivingSession(session);
          } else {
            session.syncWithClock();
            await saveCurrentDrivingSession(session);
            return session;
          }
        } else {
          // 2. Se já estava parado e é do mesmo dia civil, retorna a sessão
          if (session.date.year == now.year && session.date.month == now.month && session.date.day == now.day) {
            return session;
          } else {
            // Se for de um dia anterior e teve atividade, arquiva automaticamente no histórico
            if (session.totalDrivingSeconds > 0 || (session.startKm != null && session.startKm! > 0) || session.logs.isNotEmpty) {
              await archiveDrivingSession(session);
            }
          }
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

  // Arquivar sessão de condução no histórico diário (evita duplicados e ordena por data decrescente)
  static Future<void> archiveDrivingSession(DrivingShiftSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList(_keyDrivingHistory) ?? [];
    final list = listJson
        .map((item) => DrivingShiftSession.fromJson(jsonDecode(item)))
        .toList();

    final existingIdx = list.indexWhere((s) =>
        s.id == session.id ||
        (s.date.year == session.date.year &&
            s.date.month == session.date.month &&
            s.date.day == session.date.day));

    if (existingIdx >= 0) {
      list[existingIdx] = session;
    } else {
      list.insert(0, session);
    }

    list.sort((a, b) => b.date.compareTo(a.date));

    final updatedJson = list.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyDrivingHistory, updatedJson);
    if (CloudSyncService.isLoggedIn) {
      CloudSyncService.syncAllToCloud();
    }
  }

  // Carregar histórico de sessões de condução
  static Future<List<DrivingShiftSession>> loadDrivingHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyDrivingHistory);
      if (listJson != null) {
        final list = listJson
            .map((item) => DrivingShiftSession.fromJson(jsonDecode(item)))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      }
    } catch (e) {
      // Erro ao carregar
    }
    return [];
  }

  // Eliminar uma sessão arquivada do histórico
  static Future<void> deleteDrivingSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadDrivingHistory();
    history.removeWhere((s) => s.id == sessionId);
    final updatedJson = history.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyDrivingHistory, updatedJson);
    if (CloudSyncService.isLoggedIn) {
      CloudSyncService.syncAllToCloud();
    }
  }

  // Obter sessão de condução correspondente a uma data específica (atual ou histórico)
  static Future<DrivingShiftSession?> getDrivingSessionForDate(DateTime date) async {
    try {
      // 1. Verificar se é hoje e tem registo ativo
      final current = await loadCurrentDrivingSession();
      if (current.date.year == date.year && current.date.month == date.month && current.date.day == date.day) {
        if (current.totalDrivingSeconds > 0 || (current.startKm != null && current.startKm! > 0) || current.totalKmDriven > 0) {
          return current;
        }
      }
    } catch (_) {}

    // 2. Procurar no histórico arquivado
    final history = await loadDrivingHistory();
    for (final s in history) {
      if (s.date.year == date.year && s.date.month == date.month && s.date.day == date.day) {
        return s;
      }
    }
    return null;
  }

  // ==========================================
  // CÓPIA DE SEGURANÇA E TRANSFERÊNCIA DE DADOS
  // ==========================================

  /// Exporta todos os dados do VoltDrive (Perfil Zoe, Turnos, Metas, Sessões) em formato JSON
  static Future<String> exportFullBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await loadVehicleProfile();
    final shifts = await loadShifts();
    final goals = await loadFinancialGoals();
    final monthlyExpenses = await loadMonthlyExpenses();
    final drivingHistory = await loadDrivingHistory();
    final suggestions = await loadAppSuggestions();
    final userEmail = prefs.getString('voltdrive_auth_user_email') ?? '';

    final backup = {
      'app': 'VoltDrive',
      'version': UpdateService.currentVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'userEmail': userEmail,
      'vehicleProfile': profile.toJson(),
      'shifts': shifts.map((s) => s.toJson()).toList(),
      'financialGoals': goals.toJson(),
      'monthlyExpenses': monthlyExpenses.map((m) => m.toJson()).toList(),
      'drivingHistory': drivingHistory.map((d) => d.toJson()).toList(),
      'suggestions': suggestions.map((s) => s.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Restaura todos os dados a partir de uma cópia de segurança JSON
  static Future<int> importFullBackup(String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    if (data['app'] != 'VoltDrive' && !data.containsKey('shifts') && !data.containsKey('vehicleProfile')) {
      throw const FormatException('Ficheiro de cópia de segurança inválido para o VoltDrive.');
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Restaurar Perfil do Veículo
    if (data['vehicleProfile'] != null) {
      final profile = VehicleProfile.fromJson(Map<String, dynamic>.from(data['vehicleProfile']));
      await saveVehicleProfile(profile);
    }

    // 2. Restaurar Metas Financeiras
    if (data['financialGoals'] != null) {
      final goals = FinancialGoals.fromJson(Map<String, dynamic>.from(data['financialGoals']));
      await saveFinancialGoals(goals);
    }

    // 2.1 Restaurar Despesas Mensais
    if (data['monthlyExpenses'] != null) {
      final list = (data['monthlyExpenses'] as List)
          .map((item) => MonthlyExpense.fromJson(item as Map<String, dynamic>))
          .toList();
      await saveMonthlyExpenses(list);
    }

    // 3. Restaurar Histórico de Condução / Horas
    if (data['drivingHistory'] != null) {
      final list = (data['drivingHistory'] as List)
          .map((item) => jsonEncode(item))
          .toList();
      await prefs.setStringList(_keyDrivingHistory, list);
    }

    // 4. Restaurar Email do Utilizador se presente
    if (data['userEmail'] != null && (data['userEmail'] as String).isNotEmpty) {
      await prefs.setString('voltdrive_auth_user_email', data['userEmail']);
    }

    // 5. Restaurar Turnos Financeiros
    int shiftCount = 0;
    if (data['shifts'] != null) {
      final list = (data['shifts'] as List)
          .map((item) => jsonEncode(item))
          .toList();
      await prefs.setStringList(_keyShifts, list);
      shiftCount = list.length;
    }

    // 6. Restaurar Pasta de Sugestões
    if (data['suggestions'] != null) {
      final list = (data['suggestions'] as List)
          .map((item) => jsonEncode(item))
          .toList();
      await prefs.setStringList(_keyAppSuggestions, list);
    }

    return shiftCount;
  }

  // ==========================================
  // PASTA DE SUGESTÕES E IDEIAS
  // ==========================================

  /// Carrega todas as sugestões guardadas na pasta
  static Future<List<AppSuggestion>> loadAppSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyAppSuggestions);
      if (listJson != null && listJson.isNotEmpty) {
        final list = listJson
            .map((item) => AppSuggestion.fromJson(jsonDecode(item)))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// Guarda ou atualiza uma sugestão na pasta
  static Future<void> saveAppSuggestion(AppSuggestion suggestion) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadAppSuggestions();
    final idx = list.indexWhere((s) => s.id == suggestion.id);
    if (idx >= 0) {
      list[idx] = suggestion;
    } else {
      list.insert(0, suggestion);
    }
    final updatedJson = list.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyAppSuggestions, updatedJson);
  }

  /// Elimina uma sugestão da pasta
  static Future<void> deleteAppSuggestion(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadAppSuggestions();
    list.removeWhere((s) => s.id == id);
    final updatedJson = list.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyAppSuggestions, updatedJson);
  }
}
