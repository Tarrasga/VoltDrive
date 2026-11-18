class VehiclePreset {
  final String brand;
  final String model;
  final String fullName;
  final double batteryCapacityKwh;
  final double avgConsumptionKwh100;
  final double maxAcPowerKw;
  final String category; // '100% Elétrico', 'Híbrido'

  const VehiclePreset({
    required this.brand,
    required this.model,
    required this.fullName,
    required this.batteryCapacityKwh,
    required this.avgConsumptionKwh100,
    required this.maxAcPowerKw,
    this.category = '100% Elétrico',
  });

  String get summary => '${batteryCapacityKwh.toStringAsFixed(0)} kWh • ${avgConsumptionKwh100.toStringAsFixed(1)} kWh/100km • ${maxAcPowerKw.toStringAsFixed(0)} kW AC';

  static const List<VehiclePreset> allPresets = [
    // RENAULT
    VehiclePreset(
      brand: 'Renault',
      model: 'Zoe Z.E. 50 (R110/R135)',
      fullName: 'Renault Zoe Z.E. 50 (22kW AC)',
      batteryCapacityKwh: 52.0,
      avgConsumptionKwh100: 18.6,
      maxAcPowerKw: 22.0,
    ),
    VehiclePreset(
      brand: 'Renault',
      model: 'Zoe Z.E. 40 (R90/Q90)',
      fullName: 'Renault Zoe Z.E. 40 (22kW AC)',
      batteryCapacityKwh: 41.0,
      avgConsumptionKwh100: 17.5,
      maxAcPowerKw: 22.0,
    ),
    VehiclePreset(
      brand: 'Renault',
      model: 'Megane E-Tech EV60',
      fullName: 'Renault Megane E-Tech EV60',
      batteryCapacityKwh: 60.0,
      avgConsumptionKwh100: 16.2,
      maxAcPowerKw: 22.0,
    ),
    VehiclePreset(
      brand: 'Renault',
      model: 'Scenic E-Tech EV87',
      fullName: 'Renault Scenic E-Tech EV87',
      batteryCapacityKwh: 87.0,
      avgConsumptionKwh100: 17.2,
      maxAcPowerKw: 22.0,
    ),
    VehiclePreset(
      brand: 'Renault',
      model: '5 E-Tech 52 kWh',
      fullName: 'Renault 5 E-Tech (52 kWh)',
      batteryCapacityKwh: 52.0,
      avgConsumptionKwh100: 15.0,
      maxAcPowerKw: 11.0,
    ),

    // TESLA
    VehiclePreset(
      brand: 'Tesla',
      model: 'Model 3 Standard (LFP)',
      fullName: 'Tesla Model 3 RWD (60 kWh)',
      batteryCapacityKwh: 60.0,
      avgConsumptionKwh100: 14.2,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Tesla',
      model: 'Model 3 Long Range',
      fullName: 'Tesla Model 3 Long Range (75 kWh)',
      batteryCapacityKwh: 75.0,
      avgConsumptionKwh100: 14.8,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Tesla',
      model: 'Model Y Standard (LFP)',
      fullName: 'Tesla Model Y RWD (60 kWh)',
      batteryCapacityKwh: 60.0,
      avgConsumptionKwh100: 15.7,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Tesla',
      model: 'Model Y Long Range',
      fullName: 'Tesla Model Y Long Range (75 kWh)',
      batteryCapacityKwh: 75.0,
      avgConsumptionKwh100: 16.5,
      maxAcPowerKw: 11.0,
    ),

    // MG MOTOR
    VehiclePreset(
      brand: 'MG',
      model: 'MG4 EV Standard (LFP)',
      fullName: 'MG4 EV Standard (51 kWh)',
      batteryCapacityKwh: 51.0,
      avgConsumptionKwh100: 15.5,
      maxAcPowerKw: 6.6,
    ),
    VehiclePreset(
      brand: 'MG',
      model: 'MG4 EV Comfort / Luxury',
      fullName: 'MG4 EV Luxury (64 kWh)',
      batteryCapacityKwh: 64.0,
      avgConsumptionKwh100: 16.0,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'MG',
      model: 'MG5 EV Long Range',
      fullName: 'MG5 EV Long Range (61 kWh)',
      batteryCapacityKwh: 61.1,
      avgConsumptionKwh100: 16.5,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'MG',
      model: 'MG ZS EV Standard',
      fullName: 'MG ZS EV Standard (51 kWh)',
      batteryCapacityKwh: 51.1,
      avgConsumptionKwh100: 17.3,
      maxAcPowerKw: 6.6,
    ),

    // BYD
    VehiclePreset(
      brand: 'BYD',
      model: 'Dolphin Comfort',
      fullName: 'BYD Dolphin (60.4 kWh)',
      batteryCapacityKwh: 60.4,
      avgConsumptionKwh100: 15.2,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'BYD',
      model: 'Atto 3 Design',
      fullName: 'BYD Atto 3 (60.5 kWh)',
      batteryCapacityKwh: 60.5,
      avgConsumptionKwh100: 16.0,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'BYD',
      model: 'Seal RWD Design',
      fullName: 'BYD Seal (82.5 kWh)',
      batteryCapacityKwh: 82.5,
      avgConsumptionKwh100: 16.6,
      maxAcPowerKw: 11.0,
    ),

    // PEUGEOT / CITROËN / STELLANTIS
    VehiclePreset(
      brand: 'Peugeot',
      model: 'e-208 GT / Allure',
      fullName: 'Peugeot e-208 (50 kWh)',
      batteryCapacityKwh: 50.0,
      avgConsumptionKwh100: 15.4,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Peugeot',
      model: 'e-2008 SUV',
      fullName: 'Peugeot e-2008 (54 kWh)',
      batteryCapacityKwh: 54.0,
      avgConsumptionKwh100: 16.2,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Citroën',
      model: 'ë-C4 Shine',
      fullName: 'Citroën ë-C4 (50 kWh)',
      batteryCapacityKwh: 50.0,
      avgConsumptionKwh100: 15.3,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Opel',
      model: 'Corsa-e',
      fullName: 'Opel Corsa-e (50 kWh)',
      batteryCapacityKwh: 50.0,
      avgConsumptionKwh100: 15.8,
      maxAcPowerKw: 11.0,
    ),

    // KIA / HYUNDAI
    VehiclePreset(
      brand: 'Kia',
      model: 'Niro EV (2.ª Geração)',
      fullName: 'Kia Niro EV (64.8 kWh)',
      batteryCapacityKwh: 64.8,
      avgConsumptionKwh100: 15.7,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Kia',
      model: 'EV6 RWD Long Range',
      fullName: 'Kia EV6 RWD (77.4 kWh)',
      batteryCapacityKwh: 77.4,
      avgConsumptionKwh100: 16.5,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Hyundai',
      model: 'Kona Electric 64 kWh',
      fullName: 'Hyundai Kona Electric (64 kWh)',
      batteryCapacityKwh: 64.0,
      avgConsumptionKwh100: 15.2,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Hyundai',
      model: 'Ioniq 5 Long Range',
      fullName: 'Hyundai Ioniq 5 (77.4 kWh)',
      batteryCapacityKwh: 77.4,
      avgConsumptionKwh100: 17.0,
      maxAcPowerKw: 11.0,
    ),

    // NISSAN
    VehiclePreset(
      brand: 'Nissan',
      model: 'Leaf 40 kWh (Acenta/N-Connecta)',
      fullName: 'Nissan Leaf (40 kWh)',
      batteryCapacityKwh: 40.0,
      avgConsumptionKwh100: 16.5,
      maxAcPowerKw: 6.6,
    ),
    VehiclePreset(
      brand: 'Nissan',
      model: 'Leaf e+ 62 kWh (Tekna)',
      fullName: 'Nissan Leaf e+ (62 kWh)',
      batteryCapacityKwh: 62.0,
      avgConsumptionKwh100: 17.5,
      maxAcPowerKw: 6.6,
    ),
    VehiclePreset(
      brand: 'Nissan',
      model: 'Ariya 63 kWh',
      fullName: 'Nissan Ariya (63 kWh)',
      batteryCapacityKwh: 63.0,
      avgConsumptionKwh100: 17.6,
      maxAcPowerKw: 22.0,
    ),

    // VOLKSWAGEN / CUPRA / SKODA
    VehiclePreset(
      brand: 'Volkswagen',
      model: 'ID.3 Pro Performance',
      fullName: 'Volkswagen ID.3 Pro (58 kWh)',
      batteryCapacityKwh: 58.0,
      avgConsumptionKwh100: 15.5,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Volkswagen',
      model: 'ID.4 Pro',
      fullName: 'Volkswagen ID.4 Pro (77 kWh)',
      batteryCapacityKwh: 77.0,
      avgConsumptionKwh100: 17.2,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Cupra',
      model: 'Born e-Boost',
      fullName: 'Cupra Born (58 kWh)',
      batteryCapacityKwh: 58.0,
      avgConsumptionKwh100: 15.7,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Skoda',
      model: 'Enyaq iV 80',
      fullName: 'Skoda Enyaq iV (77 kWh)',
      batteryCapacityKwh: 77.0,
      avgConsumptionKwh100: 17.5,
      maxAcPowerKw: 11.0,
    ),

    // DACIA
    VehiclePreset(
      brand: 'Dacia',
      model: 'Spring Electric 45/65',
      fullName: 'Dacia Spring Electric (26.8 kWh)',
      batteryCapacityKwh: 26.8,
      avgConsumptionKwh100: 13.9,
      maxAcPowerKw: 6.6,
    ),

    // BMW / MERCEDES
    VehiclePreset(
      brand: 'BMW',
      model: 'i3 120 Ah',
      fullName: 'BMW i3 120 Ah (42.2 kWh)',
      batteryCapacityKwh: 42.2,
      avgConsumptionKwh100: 15.3,
      maxAcPowerKw: 11.0,
    ),
    VehiclePreset(
      brand: 'Mercedes-Benz',
      model: 'EQA 250 / EQB 250',
      fullName: 'Mercedes-Benz EQB (66.5 kWh)',
      batteryCapacityKwh: 66.5,
      avgConsumptionKwh100: 17.8,
      maxAcPowerKw: 11.0,
    ),
  ];
}
