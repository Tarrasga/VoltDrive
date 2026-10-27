class VehicleProfile {
  String name;                 // Ex: Renault Zoe Z.E. 50 / Tesla Model 3 / MG4
  double batteryCapacityKwh;   // Ex: 52.0 kWh (Renault Zoe) ou 60.0 kWh
  double avgConsumptionKwh100; // Ex: 18.6 kWh / 100 km (186 Wh/km conforme ABRP)
  double maxAcPowerKw;         // Ex: 22.0 kW (Carregamento AC Camaleão do Zoe)
  double homeKwhPrice;         // Ex: 0.16 €/kWh
  double publicKwhPrice;       // Ex: 0.32 €/kWh
  double platformFeePercent;   // Ex: 25.0% (Uber/Bolt média retida)
  double fleetCommissionPercent; // Ex: 0.0% se empresa própria, ou 40/50% se parceiro
  double targetDailyProfit;    // Ex: 120.0 € meta de lucro líquido

  VehicleProfile({
    this.name = 'Renault Zoe Z.E. 50 R110',
    this.batteryCapacityKwh = 52.0,
    this.avgConsumptionKwh100 = 18.6,
    this.maxAcPowerKw = 22.0,
    this.homeKwhPrice = 0.16,
    this.publicKwhPrice = 0.32,
    this.platformFeePercent = 25.0,
    this.fleetCommissionPercent = 0.0,
    this.targetDailyProfit = 120.0,
  });

  // Custo elétrico estimado por quilómetro rodado (€/km)
  double get energyCostPerKmPublic => (avgConsumptionKwh100 / 100.0) * publicKwhPrice;
  double get energyCostPerKmHome => (avgConsumptionKwh100 / 100.0) * homeKwhPrice;

  Map<String, dynamic> toJson() => {
    'name': name,
    'batteryCapacityKwh': batteryCapacityKwh,
    'avgConsumptionKwh100': avgConsumptionKwh100,
    'maxAcPowerKw': maxAcPowerKw,
    'homeKwhPrice': homeKwhPrice,
    'publicKwhPrice': publicKwhPrice,
    'platformFeePercent': platformFeePercent,
    'fleetCommissionPercent': fleetCommissionPercent,
    'targetDailyProfit': targetDailyProfit,
  };

  factory VehicleProfile.fromJson(Map<String, dynamic> json) => VehicleProfile(
    name: json['name'] as String? ?? 'Renault Zoe Z.E. 50 R110',
    batteryCapacityKwh: (json['batteryCapacityKwh'] as num?)?.toDouble() ?? 52.0,
    avgConsumptionKwh100: (json['avgConsumptionKwh100'] as num?)?.toDouble() ?? 18.6,
    maxAcPowerKw: (json['maxAcPowerKw'] as num?)?.toDouble() ?? 22.0,
    homeKwhPrice: (json['homeKwhPrice'] as num?)?.toDouble() ?? 0.16,
    publicKwhPrice: (json['publicKwhPrice'] as num?)?.toDouble() ?? 0.32,
    platformFeePercent: (json['platformFeePercent'] as num?)?.toDouble() ?? 25.0,
    fleetCommissionPercent: (json['fleetCommissionPercent'] as num?)?.toDouble() ?? 0.0,
    targetDailyProfit: (json['targetDailyProfit'] as num?)?.toDouble() ?? 120.0,
  );
}
