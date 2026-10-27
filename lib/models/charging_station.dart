enum ChargerSpeedCategory {
  acNormal,      // 7.4 kW - 22 kW (AC)
  dcRapido,      // 50 kW - 90 kW (DC Rápido)
  dcUltrarrapido // 100 kW - 350 kW (DC Ultrarrápido)
}

class ChargingStation {
  final String id;
  final String name;
  final String operatorName;
  final String city;
  final String address;
  final double powerKw;
  final ChargerSpeedCategory category;
  final List<String> plugTypes; // 'CCS2', 'Tipo 2', 'CHAdeMO'
  final int totalPlugs;
  final int availablePlugs;
  final double estimatedPricePerKwh;
  final double latitude;
  final double longitude;
  final bool is24h;

  ChargingStation({
    required this.id,
    required this.name,
    required this.operatorName,
    required this.city,
    required this.address,
    required this.powerKw,
    required this.category,
    required this.plugTypes,
    required this.totalPlugs,
    required this.availablePlugs,
    required this.estimatedPricePerKwh,
    required this.latitude,
    required this.longitude,
    this.is24h = true,
  });

  String get categoryLabel {
    switch (category) {
      case ChargerSpeedCategory.acNormal:
        return 'Normal AC (${powerKw.toInt()} kW)';
      case ChargerSpeedCategory.dcRapido:
        return 'Rápido DC (${powerKw.toInt()} kW)';
      case ChargerSpeedCategory.dcUltrarrapido:
        return 'Ultrarrápido (${powerKw.toInt()} kW)';
    }
  }

  // Estimar tempo para carregar X kWh (em minutos)
  int estimateChargingMinutes(double kwhNeeded) {
    if (powerKw <= 0) return 0;
    // Considera uma eficiência média de 90%
    final effectiveKw = powerKw * 0.90;
    final hours = kwhNeeded / effectiveKw;
    return (hours * 60).round();
  }

  // Estimar custo total de carregar X kWh
  double estimateChargingCost(double kwhNeeded) {
    return kwhNeeded * estimatedPricePerKwh;
  }
}
