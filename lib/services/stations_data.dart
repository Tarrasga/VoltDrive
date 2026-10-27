import '../models/charging_station.dart';

enum StationSortOption {
  closest,   // Mais Próximo
  power,     // Maior Potência
  price,     // Menor Preço
  available, // Mais Vagas Livres
}

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
    ChargingStation(
      id: 'pt_sei_04',
      name: 'Hub RioSul Shopping - Powerdot',
      operatorName: 'Powerdot / Mobi.E',
      city: 'Seixal',
      address: 'Av. Libertador Vermelho, Rio de Mouro / Seixal',
      powerKw: 100.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 6,
      availablePlugs: 4,
      estimatedPricePerKwh: 0.33,
      latitude: 38.6120,
      longitude: -9.1080,
    ),
    ChargingStation(
      id: 'pt_alm_01',
      name: 'Hub Almada Forum - Galp Electric',
      operatorName: 'Galp / Mobi.E',
      city: 'Almada',
      address: 'Rua Sérgio Malpique, Almada Forum',
      powerKw: 120.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 8,
      availablePlugs: 5,
      estimatedPricePerKwh: 0.34,
      latitude: 38.6605,
      longitude: -9.1755,
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
      id: 'pt_alm_03',
      name: 'Galp Electric - Pragal / Hospital Garcia de Orta',
      operatorName: 'Galp / Mobi.E',
      city: 'Almada',
      address: 'Av. Torrado da Silva, Pragal',
      powerKw: 90.0,
      category: ChargerSpeedCategory.dcRapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 4,
      availablePlugs: 2,
      estimatedPricePerKwh: 0.32,
      latitude: 38.6710,
      longitude: -9.1770,
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
      id: 'pt_bar_01',
      name: 'Prio - Terminal Fluvial do Barreiro',
      operatorName: 'Prio / Mobi.E',
      city: 'Barreiro',
      address: 'Rua 20 de Abril, Barreiro',
      powerKw: 50.0,
      category: ChargerSpeedCategory.dcRapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 2,
      availablePlugs: 1,
      estimatedPricePerKwh: 0.30,
      latitude: 38.6510,
      longitude: -9.0760,
    ),
    ChargingStation(
      id: 'pt_mon_01',
      name: 'Hub Alegro Montijo Ultrarrápido',
      operatorName: 'Powerdot / Mobi.E',
      city: 'Montijo',
      address: 'Zona Comercial Alegro, Montijo',
      powerKw: 150.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 6,
      availablePlugs: 3,
      estimatedPricePerKwh: 0.34,
      latitude: 38.6970,
      longitude: -8.9430,
    ),
    ChargingStation(
      id: 'pt_set_01',
      name: 'Hub Alegro Setúbal - Galp Electric',
      operatorName: 'Galp / Mobi.E',
      city: 'Setúbal',
      address: 'Av. António Sérgio, Setúbal',
      powerKw: 150.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 6,
      availablePlugs: 4,
      estimatedPricePerKwh: 0.35,
      latitude: 38.5380,
      longitude: -8.8780,
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
    ChargingStation(
      id: 'pt_lis_04',
      name: 'Hub Parque das Nações / Gare do Oriente',
      operatorName: 'EDP / Mobi.E',
      city: 'Lisboa',
      address: 'Av. Dom João II, Parque das Nações',
      powerKw: 150.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 8,
      availablePlugs: 4,
      estimatedPricePerKwh: 0.35,
      latitude: 38.7680,
      longitude: -9.0980,
    ),
    ChargingStation(
      id: 'pt_lis_05',
      name: 'BP Pulse - Praça de Espanha / Sete Rios',
      operatorName: 'BP Pulse / Mobi.E',
      city: 'Lisboa',
      address: 'Praça de Espanha, Sete Rios',
      powerKw: 120.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 4,
      availablePlugs: 2,
      estimatedPricePerKwh: 0.35,
      latitude: 38.7390,
      longitude: -9.1610,
    ),
    ChargingStation(
      id: 'pt_ama_01',
      name: 'Hub UBBO Alta Potência - Powerdot',
      operatorName: 'Powerdot / Mobi.E',
      city: 'Amadora',
      address: 'Centro Comercial UBBO, Amadora',
      powerKw: 180.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 12,
      availablePlugs: 8,
      estimatedPricePerKwh: 0.34,
      latitude: 38.7700,
      longitude: -9.2190,
    ),
    ChargingStation(
      id: 'pt_cas_01',
      name: 'Hub CascaiShopping - Galp Electric',
      operatorName: 'Galp / Mobi.E',
      city: 'Cascais',
      address: 'Estrada Nacional 9, Alcabideche',
      powerKw: 150.0,
      category: ChargerSpeedCategory.dcUltrarrapido,
      plugTypes: ['CCS2', 'CHAdeMO', 'Tipo 2'],
      totalPlugs: 8,
      availablePlugs: 5,
      estimatedPricePerKwh: 0.35,
      latitude: 38.7360,
      longitude: -9.4010,
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
    double? userLat,
    double? userLng,
    StationSortOption sortBy = StationSortOption.closest,
  }) {
    final list = portugalStations.where((st) {
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

    switch (sortBy) {
      case StationSortOption.closest:
        if (userLat != null && userLng != null) {
          list.sort((a, b) =>
              a.distanceTo(userLat, userLng).compareTo(b.distanceTo(userLat, userLng)));
        }
        break;
      case StationSortOption.power:
        list.sort((a, b) => b.powerKw.compareTo(a.powerKw));
        break;
      case StationSortOption.price:
        list.sort((a, b) => a.estimatedPricePerKwh.compareTo(b.estimatedPricePerKwh));
        break;
      case StationSortOption.available:
        list.sort((a, b) => b.availablePlugs.compareTo(a.availablePlugs));
        break;
    }

    return list;
  }

  static List<String> get availableCities {
    final cities = portugalStations.map((s) => s.city).toSet().toList();
    cities.sort();
    return ['Todas', ...cities];
  }
}
