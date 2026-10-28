class DailyShift {
  final String id;
  final DateTime date;
  final double driverEarnings; // Dinheiro ganho que fica para o condutor ("o que fica para mim")
  final double uberGross;      // Mantido para compatibilidade de registos antigos
  final double boltGross;      // Mantido para compatibilidade de registos antigos
  final double tips;           // Gorjetas / extras recebidos
  final double startKm;        // Km no início do turno (odómetro)
  final double endKm;          // Km no fim do turno (odómetro)
  final double _manualTotalKm; // Km total manual se não usar odómetro
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
    this.driverEarnings = 0.0,
    this.uberGross = 0.0,
    this.boltGross = 0.0,
    this.tips = 0.0,
    this.startKm = 0.0,
    this.endKm = 0.0,
    double totalKm = 0.0,
    this.chargingCost = 0.0,
    this.chargingKwh = 0.0,
    this.tollsCost = 0.0,
    this.otherExpenses = 0.0,
    this.hoursWorked = 0.0,
    this.notes = '',
    this.platformFeePercent = 25.0,
    this.fleetCommissionPercent = 0.0,
  }) : _manualTotalKm = totalKm;

  // Quilómetros totais calculados (se endKm > startKm) ou valor manual
  double get totalKm {
    if (endKm > startKm && startKm > 0) {
      return endKm - startKm;
    }
    return _manualTotalKm;
  }

  // Faturação / Ganho Total antes de despesas (se tiver driverEarnings usa direto; caso contrário histórico Uber+Bolt+Tips)
  double get totalGross {
    if (driverEarnings > 0) {
      return driverEarnings + tips;
    }
    return uberGross + boltGross + tips;
  }

  // Faturação de plataformas sujeita a taxas (histórico)
  double get appsGross => uberGross + boltGross;

  // Valor retido pelas plataformas (ex: 25%) no histórico
  double get platformFeeAmount {
    if (driverEarnings > 0) return 0.0;
    return appsGross * (platformFeePercent / 100.0);
  }

  // Valor após plataformas (histórico)
  double get afterPlatform => appsGross - platformFeeAmount;

  // Comissão de parceiro/frota (se for o caso no histórico)
  double get fleetCommissionAmount {
    if (driverEarnings > 0) return 0.0;
    return afterPlatform * (fleetCommissionPercent / 100.0);
  }

  // Faturação líquida que entra no bolso do condutor pelas viagens
  double get netRevenue {
    if (driverEarnings > 0) {
      return driverEarnings + tips;
    }
    return (afterPlatform - fleetCommissionAmount) + tips;
  }

  // Despesas operacionais totais do dia
  double get totalExpenses => chargingCost + tollsCost + otherExpenses;

  // Lucro Líquido Real que fica na conta (Receita Líquida - Despesas do Carro)
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
    'driverEarnings': driverEarnings,
    'uberGross': uberGross,
    'boltGross': boltGross,
    'tips': tips,
    'startKm': startKm,
    'endKm': endKm,
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
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    driverEarnings: (json['driverEarnings'] as num?)?.toDouble() ?? 0.0,
    uberGross: (json['uberGross'] as num?)?.toDouble() ?? 0.0,
    boltGross: (json['boltGross'] as num?)?.toDouble() ?? 0.0,
    tips: (json['tips'] as num?)?.toDouble() ?? 0.0,
    startKm: (json['startKm'] as num?)?.toDouble() ?? 0.0,
    endKm: (json['endKm'] as num?)?.toDouble() ?? 0.0,
    totalKm: (json['totalKm'] as num?)?.toDouble() ?? 0.0,
    chargingCost: (json['chargingCost'] as num?)?.toDouble() ?? 0.0,
    chargingKwh: (json['chargingKwh'] as num?)?.toDouble() ?? 0.0,
    tollsCost: (json['tollsCost'] as num?)?.toDouble() ?? 0.0,
    otherExpenses: (json['otherExpenses'] as num?)?.toDouble() ?? 0.0,
    hoursWorked: (json['hoursWorked'] as num?)?.toDouble() ?? 0.0,
    notes: json['notes'] as String? ?? '',
    platformFeePercent: (json['platformFeePercent'] as num?)?.toDouble() ?? 25.0,
    fleetCommissionPercent: (json['fleetCommissionPercent'] as num?)?.toDouble() ?? 0.0,
  );
}
