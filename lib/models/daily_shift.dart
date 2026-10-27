class DailyShift {
  final String id;
  final DateTime date;
  final double uberGross;
  final double boltGross;
  final double tips;
  final double totalKm;
  final double chargingCost;
  final double chargingKwh;
  final double tollsCost;
  final double otherExpenses;
  final double hoursWorked;
  final String notes;

  // Parâmetros de cálculo gravados com o turno
  final double platformFeePercent;
  final double fleetCommissionPercent;

  DailyShift({
    required this.id,
    required this.date,
    this.uberGross = 0.0,
    this.boltGross = 0.0,
    this.tips = 0.0,
    this.totalKm = 0.0,
    this.chargingCost = 0.0,
    this.chargingKwh = 0.0,
    this.tollsCost = 0.0,
    this.otherExpenses = 0.0,
    this.hoursWorked = 8.0,
    this.notes = '',
    this.platformFeePercent = 25.0,
    this.fleetCommissionPercent = 0.0,
  });

  // Faturação Bruta Total (Uber + Bolt + Tips)
  double get totalGross => uberGross + boltGross + tips;

  // Faturação de plataformas sujeita a taxas
  double get appsGross => uberGross + boltGross;

  // Valor retido pelas plataformas (ex: 25%)
  double get platformFeeAmount => appsGross * (platformFeePercent / 100.0);

  // Valor após plataformas
  double get afterPlatform => appsGross - platformFeeAmount;

  // Comissão de parceiro/frota (se for o caso)
  double get fleetCommissionAmount => afterPlatform * (fleetCommissionPercent / 100.0);

  // Faturação líquida de comissões (incluindo 100% das gorjetas)
  double get netRevenue => (afterPlatform - fleetCommissionAmount) + tips;

  // Despesas operacionais totais do dia
  double get totalExpenses => chargingCost + tollsCost + otherExpenses;

  // Lucro Líquido Real que fica na conta
  double get netProfit => netRevenue - totalExpenses;

  // Rentabilidade por km rodado
  double get profitPerKm => totalKm > 0 ? (netProfit / totalKm) : 0.0;

  // Rentabilidade por hora trabalhada
  double get profitPerHour => hoursWorked > 0 ? (netProfit / hoursWorked) : 0.0;

  // Custo operacional por km (eletricidade + portagens + outros)
  double get expensePerKm => totalKm > 0 ? (totalExpenses / totalKm) : 0.0;

  // Média de consumo kwh/100km se tiver registado kwh
  double get avgKwhPer100Km => (totalKm > 0 && chargingKwh > 0) ? ((chargingKwh / totalKm) * 100.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'uberGross': uberGross,
    'boltGross': boltGross,
    'tips': tips,
    'totalKm': totalKm,
    'chargingCost': chargingCost,
    'chargingKwh': chargingKwh,
    'tollsCost': tollsCost,
    'otherExpenses': otherExpenses,
    'hoursWorked': hoursWorked,
    'notes': notes,
    'platformFeePercent': platformFeePercent,
    'fleetCommissionPercent': fleetCommissionPercent,
  };

  factory DailyShift.fromJson(Map<String, dynamic> json) => DailyShift(
    id: json['id'] as String? ?? UniqueKey().toString(),
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    uberGross: (json['uberGross'] as num?)?.toDouble() ?? 0.0,
    boltGross: (json['boltGross'] as num?)?.toDouble() ?? 0.0,
    tips: (json['tips'] as num?)?.toDouble() ?? 0.0,
    totalKm: (json['totalKm'] as num?)?.toDouble() ?? 0.0,
    chargingCost: (json['chargingCost'] as num?)?.toDouble() ?? 0.0,
    chargingKwh: (json['chargingKwh'] as num?)?.toDouble() ?? 0.0,
    tollsCost: (json['tollsCost'] as num?)?.toDouble() ?? 0.0,
    otherExpenses: (json['otherExpenses'] as num?)?.toDouble() ?? 0.0,
    hoursWorked: (json['hoursWorked'] as num?)?.toDouble() ?? 8.0,
    notes: json['notes'] as String? ?? '',
    platformFeePercent: (json['platformFeePercent'] as num?)?.toDouble() ?? 25.0,
    fleetCommissionPercent: (json['fleetCommissionPercent'] as num?)?.toDouble() ?? 0.0,
  );
}

class UniqueKey {
  @override
  String toString() => DateTime.now().millisecondsSinceEpoch.toString();
}
