import '../models/charging_station.dart';

class StationsData {
  static final List<ChargingStation> portugalStations = [
    // SEIXAL, ALMADA, CORROIOS (Zona da Margem Sul & Rota do Utilizador)
    ChargingStation(
      id: 'pt_sei_01',
      name: 'Powerdot - Brejos da Piedade',
      operatorName: 'Powerdot / Mobi.E',
      city: 'Seixal',
      address: 'Rua Brejos da Piedade, Seixal',
      powerKw: 43.0,
      category: ChargerSpeedCategory.dcRapido,
      plugTypes: ['Tipo 2 (43kW AC)', 'CCS2'],
      totalPlugs: 5,
      availablePlugs: 1,
      estimatedPricePerKwh: 0.31,
      latitude: 38.6250,
      longitude: -9.1150,
    ),
    ChargingStation(
      id: 'pt_alm_02',
      name: 'Renewing - Rua Sérgio Malpique',
      operatorName: 'Renewing / Mobi.E',
      city: 'Almada',
      address: 'Rua Sérgio Malpique, Almada',
      powerKw: 22.0,
      category: ChargerSpeedCategory.acNormal,
      plugTypes: ['Tipo 2'],
      totalPlugs: 10,
      availablePlugs: 4,
      estimatedPricePerKwh: 0.28,
      latitude: 38.6620,
      longitude: -9.1740,
    ),
    ChargingStation(
      id: 'pt_cor_01',
      name: 'Galp Energia - Corroios',
      operatorName: 'Galp / Mobi.E',
      city: 'Corroios',
      address: 'Av. Vieira da Silva, Corroios',
      powerKw: 22.0,
      category: ChargerSpeedCategory.acNormal,
      plugTypes: ['Tipo 2'],
      totalPlugs: 2,
      availablePlugs: 1,
      estimatedPricePerKwh: 0.29,
      latitude: 38.6430,
      longitude: -9.1520,
    ),
    ChargingStation(
      id: 'pt_sei_02',
      name: 'Powerdot - Estrada Quinta da Carcereira',
      operatorName: 'Powerdot / Mobi.E',
      city: 'Seixal',
      address: 'Estrada Quinta da Carcereira, Seixal',
      powerKw: 22.0,
      category: ChargerSpeedCategory.acNormal,
      plugTypes: ['Tipo 2'],
      totalPlugs: 2,
      availablePlugs: 1,
      estimatedPricePerKwh: 0.28,
      latitude: 38.6180,
      longitude: -9.1020,
    ),
    ChargingStation(
      id: 'pt_sei_03',
      name: 'EDP - Estrada João Bacherel',
      operatorName: 'EDP / Mobi.E',
      city: 'Seixal',
      address: 'Estrada João Bacherel, Seixal',
      powerKw: 22.0,
      category: ChargerSpeedCategory.acNormal,
      plugTypes: ['Tipo 2'],
      totalPlugs: 2,
      availablePlugs: 1,
      estimatedPricePerKwh: 0.27,
      latitude: 38.6300,
      longitude: -9.1000,
    ),

    // ROTA ALENTEJO / PONTE DE SOR / NISA
    ChargingStation(
      id: 'pt_pds_01',
      name: 'Prio - N2 Ponte de Sor',
      operatorName: 'Prio / Mobi.E',
      city: 'Ponte de Sor',
      address: 'Estrada Nacional 2, Ponte de Sor',
      powerKw: 22.0,
      category: ChargerSpeedCategory.acNormal,
      plugTypes: ['Tipo 2'],
      totalPlugs: 2,
      availablePlugs: 2,
      estimatedPricePerKwh: 0.28,
      latitude: 39.2510,
      longitude: -8.0120,
    ),
    ChargingStation(
      id: 'pt_pds_02',
      name: 'Prio - Praça da República',
      operatorName: 'Prio / Mobi.E',
      city: 'Ponte de Sor',
      address: 'Praça da República, Ponte de Sor',
      powerKw: 22.0,
      category: ChargerSpeedCategory.acNormal,
      plugTypes: ['Tipo 2'],
      totalPlugs: 2,
      availablePlugs: 2,
      estimatedPricePerKwh: 0.28,
      latitude: 39.2480,
      longitude: -8.0100,
    ),

    // LISBOA
    ChargingStation(
      id: 'pt_lis_01',
      name: 'Hub Galp Electric - Aeroporto Lisboa',
      operatorName: 'Galp / Mobi.E',
      city: 'Lisboa',
      address: 'Alameda das Comunidades Portuguesas, Aeroporto',
      powerKw: 150.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 6,
      availablePlugs: 4,
      estimatedPricePerKwh: 0.36,
      latitude: 38.7756,
      longitude: -9.1354,
    ),
    ChargingStation(
      id: 'pt_lis_02',
      name: 'Hub Powerdot - Centro Colombo',
      operatorName: 'Powerdot / Mobi.E',
      city: 'Lisboa',
      address: 'Av. Lusíada, Parque Subterrâneo Colombo',
      powerKw: 100.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'Tipo 2'],
      totalPlugs: 8,
      availablePlugs: 5,
      estimatedPricePerKwh: 0.34,
      latitude: 38.7538,
      longitude: -9.1889,
    ),
    ChargingStation(
      id: 'pt_lis_03',
      name: 'Posto Repsol - Segunda Circular (Campo Grande)',
      operatorName: 'Repsol / Mobi.E',
      city: 'Lisboa',
      address: 'Segunda Circular Sentido Benfica-Aeroporto',
      powerKw: 50.0,
      category: ChargerSpeedCategory.dcRapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 2,
      availablePlugs: 1,
      estimatedPricePerKwh: 0.32,
      latitude: 38.7612,
      longitude: -9.1558,
    ),

    // PORTO E NORTE
    ChargingStation(
      id: 'pt_opo_01',
      name: 'Hub BP Pulse - Boavista / Francos',
      operatorName: 'BP Pulse / Mobi.E',
      city: 'Porto',
      address: 'Rua de Francos, Ramalde',
      powerKw: 150.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 4,
      availablePlugs: 3,
      estimatedPricePerKwh: 0.35,
      latitude: 41.1685,
      longitude: -8.6432,
    ),
    ChargingStation(
      id: 'pt_opo_02',
      name: 'NorteShopping Hub de Alta Potência',
      operatorName: 'Galp / Mobi.E',
      city: 'Porto',
      address: 'Rua Sara Afonso, Senhora da Hora',
      powerKw: 120.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'Tipo 2'],
      totalPlugs: 6,
      availablePlugs: 4,
      estimatedPricePerKwh: 0.34,
      latitude: 41.1804,
      longitude: -8.6547,
    ),

    // CENTRO E ALGARVE
    ChargingStation(
      id: 'pt_coi_01',
      name: 'Forum Coimbra Hub',
      operatorName: 'Powerdot / Mobi.E',
      city: 'Coimbra',
      address: 'Av. José Bonifácio de Andrada e Silva',
      powerKw: 100.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 4,
      availablePlugs: 2,
      estimatedPricePerKwh: 0.33,
      latitude: 40.2105,
      longitude: -8.4418,
    ),
    ChargingStation(
      id: 'pt_far_01',
      name: 'Hub Aeroporto de Faro - Galp Electric',
      operatorName: 'Galp / Mobi.E',
      city: 'Faro',
      address: 'Aeroporto Internacional de Faro',
      powerKw: 150.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 4,
      availablePlugs: 3,
      estimatedPricePerKwh: 0.36,
      latitude: 37.0178,
      longitude: -7.9691,
    ),
  ];

  static List<ChargingStation> filterStations({
    String query = '',
    ChargerSpeedCategory? category,
    String? city,
  }) {
    return portugalStations.where((st) {
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        final match = st.name.toLowerCase().contains(q) ||
            st.city.toLowerCase().contains(q) ||
            st.operatorName.toLowerCase().contains(q) ||
            st.address.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (category != null && st.category != category) {
        return false;
      }
      if (city != null && city != 'Todas' && st.city != city) {
        return false;
      }
      return true;
    }).toList();
  }

  static List<String> get availableCities {
    final cities = portugalStations.map((s) => s.city).toSet().toList();
    cities.sort();
    return ['Todas', ...cities];
  }
}
