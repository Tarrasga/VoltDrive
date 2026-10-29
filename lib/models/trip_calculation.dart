enum ProfitabilityVerdict {
  excelente, // Muito rentável (> 0.85 €/km líquido)
  aceitavel, // Rentabilidade normal (0.55 - 0.85 €/km líquido)
  fraca,     // Margem baixa / Alerta (< 0.55 €/km líquido)
  prejuizo,  // Custo supera ou iguala o ganho líquido
}

class TripCalculation {
  final double grossFare;        // Valor total proposto na app Uber/Bolt (€)
  final double pickupDistanceKm; // Distância até apanhar o passageiro (km)
  final double tripDistanceKm;   // Distância com passageiro no carro (km)
  final double durationMinutes;  // Duração estimada em minutos
  final double tollsCost;        // Portagens estimadas (€)
  final double energyCostPerKm;  // Custo elétrico por km (€/km)
  final double platformFeeRate;  // Ex: 0.25 (25%)
  final double fleetFeeRate;     // Ex: 0.0 (empresa própria) ou 0.40/0.50 (parceiro)
  final bool includeVehicleConsumption; // Se deve calcular/descontar consumo do carro

  TripCalculation({
    required this.grossFare,
    required this.pickupDistanceKm,
    required this.tripDistanceKm,
    this.durationMinutes = 15.0,
    this.tollsCost = 0.0,
    required this.energyCostPerKm,
    this.platformFeeRate = 0.25,
    this.fleetFeeRate = 0.0,
    this.includeVehicleConsumption = false, // Por defeito: não calcular consumo do carro
  });

  // Distância total rodada para a viagem (km)
  double get totalDistanceKm => pickupDistanceKm + tripDistanceKm;

  // Valor que sobra após taxa da plataforma Uber/Bolt (75%)
  double get fareAfterPlatform => grossFare * (1.0 - platformFeeRate);

  // Valor do motorista após frota (se aplicável)
  double get driverShare => fareAfterPlatform * (1.0 - fleetFeeRate);

  // Custo de energia elétrica (0.0 se não calcular consumo do carro)
  double get totalEnergyCost => includeVehicleConsumption ? (totalDistanceKm * energyCostPerKm) : 0.0;

  // Custos totais diretos da viagem (eletricidade + portagens)
  double get directCosts => totalEnergyCost + tollsCost;

  // Lucro Líquido Real que entra no bolso
  double get netProfit => driverShare - directCosts;

  // Lucro líquido por quilómetro rodado (€/km)
  double get netProfitPerKm => totalDistanceKm > 0 ? (netProfit / totalDistanceKm) : 0.0;

  // Lucro líquido extrapolado por hora (€/h)
  double get netProfitPerHour => durationMinutes > 0 ? (netProfit / (durationMinutes / 60.0)) : 0.0;

  // Veredito sobre aceitar ou rejeitar a viagem
  ProfitabilityVerdict get verdict {
    if (netProfit <= 0) return ProfitabilityVerdict.prejuizo;
    if (netProfitPerKm >= 0.85) return ProfitabilityVerdict.excelente;
    if (netProfitPerKm >= 0.55) return ProfitabilityVerdict.aceitavel;
    return ProfitabilityVerdict.fraca;
  }

  String get verdictText {
    switch (verdict) {
      case ProfitabilityVerdict.excelente:
        return 'Excelente Viagem!';
      case ProfitabilityVerdict.aceitavel:
        return 'Viagem Rentável';
      case ProfitabilityVerdict.fraca:
        return 'Margem Baixa (Atenção)';
      case ProfitabilityVerdict.prejuizo:
        return 'Não Compensa (Prejuízo)';
    }
  }
}
