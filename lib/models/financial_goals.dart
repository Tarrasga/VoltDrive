import 'dart:math';
import 'daily_shift.dart';

class FinancialGoals {
  final double monthlyTarget; // Ex: 2000.0 €
  final double weeklyTarget;  // Ex: 500.0 €
  final String targetType;    // 'profit' (Lucro Líquido no Bolso) ou 'revenue' (Faturação Bruta)
  final int workDaysPerWeek;  // 5, 6 ou 7 dias de trabalho por semana

  FinancialGoals({
    this.monthlyTarget = 2000.0,
    this.weeklyTarget = 500.0,
    this.targetType = 'profit',
    this.workDaysPerWeek = 6,
  });

  Map<String, dynamic> toJson() => {
    'monthlyTarget': monthlyTarget,
    'weeklyTarget': weeklyTarget,
    'targetType': targetType,
    'workDaysPerWeek': workDaysPerWeek,
  };

  factory FinancialGoals.fromJson(Map<String, dynamic> json) => FinancialGoals(
    monthlyTarget: (json['monthlyTarget'] as num?)?.toDouble() ?? 2000.0,
    weeklyTarget: (json['weeklyTarget'] as num?)?.toDouble() ?? 500.0,
    targetType: json['targetType'] as String? ?? 'profit',
    workDaysPerWeek: (json['workDaysPerWeek'] as num?)?.toInt() ?? 6,
  );

  FinancialGoals copyWith({
    double? monthlyTarget,
    double? weeklyTarget,
    String? targetType,
    int? workDaysPerWeek,
  }) => FinancialGoals(
    monthlyTarget: monthlyTarget ?? this.monthlyTarget,
    weeklyTarget: weeklyTarget ?? this.weeklyTarget,
    targetType: targetType ?? this.targetType,
    workDaysPerWeek: workDaysPerWeek ?? this.workDaysPerWeek,
  );

  /// Calcula o ritmo necessário para a Meta Mensal
  FinancialPaceCalculation calculateMonthlyPace(List<DailyShift> allShifts, {DateTime? refDate}) {
    final now = refDate ?? DateTime.now();
    final shiftsInMonth = allShifts.where((s) => s.date.year == now.year && s.date.month == now.month).toList();

    final isProfit = targetType == 'profit';
    final double achieved = shiftsInMonth.fold(
      0.0,
      (sum, s) => sum + (isProfit ? s.estimatedNetProfit : s.totalGrossEarnings),
    );

    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    // Dias restantes no mês (incluindo o dia de hoje)
    final int daysLeft = max(1, lastDayOfMonth - now.day + 1);

    // Dias de trabalho estimados restantes de acordo com folgas configuradas
    final double workRatio = (workDaysPerWeek.clamp(1, 7) / 7.0);
    final int workingDaysLeft = max(1, (daysLeft * workRatio).round());

    final double remaining = monthlyTarget - achieved;
    final bool isReached = remaining <= 0.0;

    final double requiredDailyCalendar = isReached ? 0.0 : (remaining / daysLeft);
    final double requiredDailyWorking = isReached ? 0.0 : (remaining / workingDaysLeft);

    final int workedDays = shiftsInMonth.length;
    final double currentDailyAverage = workedDays > 0 ? (achieved / workedDays) : 0.0;
    final double percentage = monthlyTarget > 0 ? ((achieved / monthlyTarget) * 100).clamp(0.0, 999.0) : 0.0;

    return FinancialPaceCalculation(
      target: monthlyTarget,
      achieved: achieved,
      remaining: remaining,
      percentage: percentage,
      daysLeft: daysLeft,
      workingDaysLeft: workingDaysLeft,
      requiredDailyPaceCalendar: requiredDailyCalendar,
      requiredDailyPaceWorking: requiredDailyWorking,
      currentDailyAverage: currentDailyAverage,
      isTargetReached: isReached,
    );
  }

  /// Calcula o ritmo necessário para a Meta Semanal
  FinancialPaceCalculation calculateWeeklyPace(List<DailyShift> allShifts, {DateTime? refDate}) {
    final now = refDate ?? DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final shiftsInWeek = allShifts.where(
      (s) => s.date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && s.date.isBefore(endOfWeek),
    ).toList();

    final isProfit = targetType == 'profit';
    final double achieved = shiftsInWeek.fold(
      0.0,
      (sum, s) => sum + (isProfit ? s.estimatedNetProfit : s.totalGrossEarnings),
    );

    // Dias que faltam na semana até Domingo (incluindo hoje)
    final int daysLeft = max(1, 7 - now.weekday + 1);

    // Dias de trabalho restantes na semana
    final int daysAlreadyWorkedThisWeek = shiftsInWeek.length;
    final int maxDaysCanWorkThisWeek = max(1, workDaysPerWeek - daysAlreadyWorkedThisWeek);
    final int workingDaysLeft = min(daysLeft, maxDaysCanWorkThisWeek);

    final double remaining = weeklyTarget - achieved;
    final bool isReached = remaining <= 0.0;

    final double requiredDailyCalendar = isReached ? 0.0 : (remaining / daysLeft);
    final double requiredDailyWorking = isReached ? 0.0 : (remaining / workingDaysLeft);

    final double currentDailyAverage = daysAlreadyWorkedThisWeek > 0 ? (achieved / daysAlreadyWorkedThisWeek) : 0.0;
    final double percentage = weeklyTarget > 0 ? ((achieved / weeklyTarget) * 100).clamp(0.0, 999.0) : 0.0;

    return FinancialPaceCalculation(
      target: weeklyTarget,
      achieved: achieved,
      remaining: remaining,
      percentage: percentage,
      daysLeft: daysLeft,
      workingDaysLeft: workingDaysLeft,
      requiredDailyPaceCalendar: requiredDailyCalendar,
      requiredDailyPaceWorking: requiredDailyWorking,
      currentDailyAverage: currentDailyAverage,
      isTargetReached: isReached,
    );
  }
}

class FinancialPaceCalculation {
  final double target;
  final double achieved;
  final double remaining;
  final double percentage;
  final int daysLeft;
  final int workingDaysLeft;
  final double requiredDailyPaceCalendar;
  final double requiredDailyPaceWorking;
  final double currentDailyAverage;
  final bool isTargetReached;

  FinancialPaceCalculation({
    required this.target,
    required this.achieved,
    required this.remaining,
    required this.percentage,
    required this.daysLeft,
    required this.workingDaysLeft,
    required this.requiredDailyPaceCalendar,
    required this.requiredDailyPaceWorking,
    required this.currentDailyAverage,
    required this.isTargetReached,
  });
}
