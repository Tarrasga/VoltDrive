import 'package:flutter/material.dart';
import '../models/charging_station.dart';
import '../models/vehicle_profile.dart';
import '../services/assistant_service.dart';
import '../services/stations_data.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ChargingStationsScreen extends StatefulWidget {
  const ChargingStationsScreen({super.key});

  @override
  State<ChargingStationsScreen> createState() => _ChargingStationsScreenState();
}

class _ChargingStationsScreenState extends State<ChargingStationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  ChargerSpeedCategory? _selectedCategory;
  String _selectedCity = 'Todas';
  VehicleProfile _profile = VehicleProfile();

  LocationResult? _userLocation;
  bool _isLoadingLocation = false;
  StationSortOption _sortOption = StationSortOption.closest;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchCurrentLocation();
  }

  Future<void> _loadProfile() async {
    final prof = await StorageService.loadVehicleProfile();
    if (mounted) {
      setState(() {
        _profile = prof;
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final loc = await AssistantService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _userLocation = loc;
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _openGpsNavigation(ChargingStation station, {bool useWaze = false}) {
    if (useWaze) {
      final wazeUrl = 'https://waze.com/ul?ll=${station.latitude},${station.longitude}&navigate=yes';
      AssistantService.openUrl(wazeUrl);
    } else {
      final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${station.latitude},${station.longitude}';
      AssistantService.openUrl(mapsUrl);
    }
  }

  void _showNavigationOptions(BuildContext context, ChargingStation station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Navegar para ${station.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  station.address,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF33CCFF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openGpsNavigation(station, useWaze: true);
                        },
                        icon: const Icon(Icons.navigation, size: 20),
                        label: const Text('Waze', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryElectric,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openGpsNavigation(station, useWaze: false);
                        },
                        icon: const Icon(Icons.map, size: 20),
                        label: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChargingEstimator(BuildContext context, ChargingStation station) {
    double currentBatteryPercent = 20.0;
    double targetBatteryPercent = 80.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final percentNeeded = (targetBatteryPercent - currentBatteryPercent).clamp(0.0, 100.0);
            final kwhNeeded = (percentNeeded / 100.0) * _profile.batteryCapacityKwh;
            final estimatedMins = station.estimateChargingMinutes(kwhNeeded);
            final estimatedCost = station.estimateChargingCost(kwhNeeded);
            final homeCost = kwhNeeded * _profile.homeKwhPrice;

            final distText = _userLocation != null
                ? station.formattedDistanceTo(_userLocation!.latitude, _userLocation!.longitude)
                : null;

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.ev_station, color: AppTheme.primaryElectric, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            Text(
                              '${station.operatorName} • Potência: ${station.powerKw.toInt()} kW${distText != null ? " • A $distText" : ""}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.darkBorder, height: 24),
                  const Text('Simulador de Carga Renault Zoe:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),

                  // SLIDERS BATERIA ATUAL -> PRETENDIDA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bateria Atual: ${currentBatteryPercent.toInt()}%', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      Text('Pretendida: ${targetBatteryPercent.toInt()}%', style: const TextStyle(color: AppTheme.primaryElectric, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: currentBatteryPercent,
                    min: 5.0,
                    max: 95.0,
                    divisions: 18,
                    activeColor: AppTheme.warningAmber,
                    onChanged: (val) {
                      setModalState(() {
                        currentBatteryPercent = val;
                        if (targetBatteryPercent <= currentBatteryPercent) {
                          targetBatteryPercent = (currentBatteryPercent + 10).clamp(10.0, 100.0);
                        }
                      });
                    },
                  ),
                  Slider(
                    value: targetBatteryPercent,
                    min: 10.0,
                    max: 100.0,
                    divisions: 18,
                    activeColor: AppTheme.accentGreen,
                    onChanged: (val) {
                      setModalState(() {
                        if (val > currentBatteryPercent) {
                          targetBatteryPercent = val;
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // RESULTADOS DA ESTIMATIVA
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Energia', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  '${kwhNeeded.toStringAsFixed(1)} kWh',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 35, color: AppTheme.darkBorder),
                            Column(
                              children: [
                                const Text('Tempo Est.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  '$estimatedMins min',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.warningAmber),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 35, color: AppTheme.darkBorder),
                            Column(
                              children: [
                                const Text('Custo Posto', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  '${estimatedCost.toStringAsFixed(2)} €',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryElectric),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Em casa (€${_profile.homeKwhPrice.toStringAsFixed(2)}/kWh) custaria aprox. ${homeCost.toStringAsFixed(2)} €',
                          style: const TextStyle(fontSize: 12, color: AppTheme.accentGreen),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openGpsNavigation(station, useWaze: true);
                          },
                          icon: const Icon(Icons.navigation, color: Color(0xFF33CCFF)),
                          label: const Text('Waze', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF33CCFF)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openGpsNavigation(station, useWaze: false);
                          },
                          icon: const Icon(Icons.map, color: Colors.black),
                          label: const Text('Google Maps', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryElectric,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = StationsData.filterStations(
      query: _searchController.text,
      category: _selectedCategory,
      city: _selectedCity,
      userLat: _userLocation?.latitude,
      userLng: _userLocation?.longitude,
      sortBy: _sortOption,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ev_station, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Postos de Carregamento VE'),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryElectric),
                  )
                : const Icon(Icons.my_location, color: AppTheme.primaryElectric),
            tooltip: 'Atualizar Localização (GPS)',
            onPressed: _isLoadingLocation ? null : _fetchCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // BARRA INFORMATIVA DE GPS
          if (_userLocation != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AppTheme.primaryElectric.withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.near_me, size: 14, color: AppTheme.primaryElectric),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Postos ordenados por distância a partir da tua localização GPS',
                      style: TextStyle(fontSize: 11, color: AppTheme.primaryElectric, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${filtered.length} postos',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),

          // CAMPO DE PESQUISA
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome, rua, cidade, operador...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryElectric),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // CRITÉRIOS DE ORDENAÇÃO
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Text('Ordenar: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                ChoiceChip(
                  avatar: const Icon(Icons.near_me, size: 14, color: AppTheme.primaryElectric),
                  label: const Text('Mais Próximos'),
                  selected: _sortOption == StationSortOption.closest,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortOption = StationSortOption.closest);
                  },
                  selectedColor: AppTheme.primaryElectric.withOpacity(0.2),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: const Icon(Icons.bolt, size: 14, color: AppTheme.warningAmber),
                  label: const Text('Maior Potência'),
                  selected: _sortOption == StationSortOption.power,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortOption = StationSortOption.power);
                  },
                  selectedColor: AppTheme.warningAmber.withOpacity(0.2),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: const Icon(Icons.euro, size: 14, color: AppTheme.accentGreen),
                  label: const Text('Menor Preço'),
                  selected: _sortOption == StationSortOption.price,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortOption = StationSortOption.price);
                  },
                  selectedColor: AppTheme.accentGreen.withOpacity(0.2),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: const Icon(Icons.ev_station, size: 14, color: Colors.cyan),
                  label: const Text('Mais Vagas'),
                  selected: _sortOption == StationSortOption.available,
                  onSelected: (sel) {
                    if (sel) setState(() => _sortOption = StationSortOption.available);
                  },
                  selectedColor: Colors.cyan.withOpacity(0.2),
                ),
              ],
            ),
          ),

          // FILTROS DE CIDADE E VELOCIDADE
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                // CIDADES
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCity,
                    dropdownColor: AppTheme.darkSurface,
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.bold, fontSize: 12),
                    items: StationsData.availableCities.map((city) {
                      return DropdownMenuItem(value: city, child: Text(city));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCity = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // FILTROS DE POTÊNCIA
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                  selectedColor: AppTheme.primaryElectric.withOpacity(0.2),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Ultrarrápido (100kW+)'),
                  selected: _selectedCategory == ChargerSpeedCategory.dcUltrarrapido,
                  onSelected: (sel) => setState(() => _selectedCategory = sel ? ChargerSpeedCategory.dcUltrarrapido : null),
                  selectedColor: AppTheme.primaryElectric.withOpacity(0.2),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Rápido (50-90kW)'),
                  selected: _selectedCategory == ChargerSpeedCategory.dcRapido,
                  onSelected: (sel) => setState(() => _selectedCategory = sel ? ChargerSpeedCategory.dcRapido : null),
                  selectedColor: AppTheme.accentGreen.withOpacity(0.2),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Normal (22kW)'),
                  selected: _selectedCategory == ChargerSpeedCategory.acNormal,
                  onSelected: (sel) => setState(() => _selectedCategory = sel ? ChargerSpeedCategory.acNormal : null),
                  selectedColor: AppTheme.warningAmber.withOpacity(0.2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // LISTA DE POSTOS
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Nenhum posto encontrado com estes filtros.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final station = filtered[index];
                      return _buildStationCard(context, station);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(BuildContext context, ChargingStation station) {
    Color speedColor = AppTheme.warningAmber;
    if (station.category == ChargerSpeedCategory.dcUltrarrapido) {
      speedColor = AppTheme.primaryElectric;
    } else if (station.category == ChargerSpeedCategory.dcRapido) {
      speedColor = AppTheme.accentGreen;
    }

    final distText = _userLocation != null
        ? station.formattedDistanceTo(_userLocation!.latitude, _userLocation!.longitude)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showChargingEstimator(context, station),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: speedColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.bolt, color: speedColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${station.city} • ${station.operatorName}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: speedColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: speedColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          '${station.powerKw.toInt()} kW',
                          style: TextStyle(color: speedColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      if (distText != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me, size: 10, color: AppTheme.primaryElectric),
                              const SizedBox(width: 3),
                              Text(
                                distText,
                                style: const TextStyle(
                                  color: AppTheme.primaryElectric,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(station.address, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const Divider(color: AppTheme.darkBorder, height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.power, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        station.plugTypes.join(' • '),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 10, color: AppTheme.accentGreen),
                      const SizedBox(width: 4),
                      Text(
                        '${station.availablePlugs}/${station.totalPlugs} Livres',
                        style: const TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '~${station.estimatedPricePerKwh.toStringAsFixed(2)} €/kWh',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryElectric, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.navigation, size: 20, color: AppTheme.primaryElectric),
                        tooltip: 'Navegar no GPS',
                        onPressed: () => _showNavigationOptions(context, station),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
