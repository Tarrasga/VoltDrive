enum DrivingState {
  parado,     // Fora de serviço / Turno terminado
  conduzindo, // Em condução ativa (Uber / Bolt)
  emPausa,    // Em descanso / Almoço / Carregamento
}

class DrivingSessionLog {
  final DateTime timestamp;
  final String description; // Ex: 'Início de Condução', 'Pausa Iniciada', etc.
  final DrivingState state;

  DrivingSessionLog({
    required this.timestamp,
    required this.description,
    required this.state,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'state': state.index,
  };

  factory DrivingSessionLog.fromJson(Map<String, dynamic> json) => DrivingSessionLog(
    timestamp: DateTime.parse(json['timestamp']),
    description: json['description'],
    state: DrivingState.values[json['state'] ?? 0],
  );
}

class DrivingShiftSession {
  // Limites Legais da Lei TVDE (Lei n.º 45/2018)
  static const int maxDailyDrivingSeconds = 10 * 3600; // 10 horas máximas por dia
  static const int maxContinuousDrivingSeconds = 4 * 3600; // 4 horas contínuas antes de pausa
  static const int minBreakSeconds = 45 * 60; // 45 minutos de pausa obrigatória

  final String id;
  final DateTime date;
  DateTime? shiftStartTime;
  DateTime? shiftEndTime;
  int totalDrivingSeconds;
  int currentContinuousDrivingSeconds;
  int totalBreakSeconds;
  DrivingState currentState;
  List<DrivingSessionLog> logs;

  DrivingShiftSession({
    required this.id,
    required this.date,
    this.shiftStartTime,
    this.shiftEndTime,
    this.totalDrivingSeconds = 0,
    this.currentContinuousDrivingSeconds = 0,
    this.totalBreakSeconds = 0,
    this.currentState = DrivingState.parado,
    List<DrivingSessionLog>? logs,
  }) : logs = logs ?? [];

  // Tempo de condução restante hoje (até ao limite de 10h da Lei TVDE)
  int get remainingDailyDrivingSeconds => (maxDailyDrivingSeconds - totalDrivingSeconds).clamp(0, maxDailyDrivingSeconds);

  // Tempo restante até à pausa obrigatória de 45 min (a cada 4 horas)
  int get remainingContinuousDrivingSeconds => (maxContinuousDrivingSeconds - currentContinuousDrivingSeconds).clamp(0, maxContinuousDrivingSeconds);

  // Percentagem das 10 horas consumida
  double get dailyUsageRatio => (totalDrivingSeconds / maxDailyDrivingSeconds).clamp(0.0, 1.0);

  // Percentagem do bloco contínuo de 4 horas consumida
  double get continuousUsageRatio => (currentContinuousDrivingSeconds / maxContinuousDrivingSeconds).clamp(0.0, 1.0);

  // Verificação de alertas
  bool get isDailyLimitReached => totalDrivingSeconds >= maxDailyDrivingSeconds;
  bool get isBreakMandatory => currentContinuousDrivingSeconds >= maxContinuousDrivingSeconds;
  bool get isNearBreakWarning => currentContinuousDrivingSeconds >= (maxContinuousDrivingSeconds - 1800); // Faltam 30 min

  String formatSeconds(int totalSecs) {
    final hours = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    final secs = totalSecs % 60;
    return '${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
  }

  String formatHoursAndMins(int totalSecs) {
    final hours = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'shiftStartTime': shiftStartTime?.toIso8601String(),
    'shiftEndTime': shiftEndTime?.toIso8601String(),
    'totalDrivingSeconds': totalDrivingSeconds,
    'currentContinuousDrivingSeconds': currentContinuousDrivingSeconds,
    'totalBreakSeconds': totalBreakSeconds,
    'currentState': currentState.index,
    'logs': logs.map((l) => l.toJson()).toList(),
  };

  factory DrivingShiftSession.fromJson(Map<String, dynamic> json) => DrivingShiftSession(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    shiftStartTime: json['shiftStartTime'] != null ? DateTime.tryParse(json['shiftStartTime']) : null,
    shiftEndTime: json['shiftEndTime'] != null ? DateTime.tryParse(json['shiftEndTime']) : null,
    totalDrivingSeconds: json['totalDrivingSeconds'] ?? 0,
    currentContinuousDrivingSeconds: json['currentContinuousDrivingSeconds'] ?? 0,
    totalBreakSeconds: json['totalBreakSeconds'] ?? 0,
    currentState: DrivingState.values[json['currentState'] ?? 0],
    logs: (json['logs'] as List<dynamic>?)?.map((l) => DrivingSessionLog.fromJson(l)).toList(),
  );
}
