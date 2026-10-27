import 'package:flutter/material.dart';
import '../models/charging_station.dart';
import '../models/vehicle_profile.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prof = await StorageService.loadVehicleProfile();
    setState(() {
      _profile = prof;
    });
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
                              '${station.operatorName} • Potência: ${station.powerKw.toInt()} kW',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.darkBorder, height: 24),
                  const Text('Simulador de Carga:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('A navegar para ${station.name}...'),
                          backgroundColor: AppTheme.primaryElectric,
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Abrir no GPS (Waze / Google Maps)'),
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
      ),
      body: Column(
        children: [
          // CAMPO DE PESQUISA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome, rua, cidade...',
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

          // FILTROS DE CIDADE E VELOCIDADE
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // CIDADES
                DropdownButton<String>(
                  value: _selectedCity,
                  dropdownColor: AppTheme.darkSurface,
                  underline: const SizedBox(),
                  style: const TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.bold, fontSize: 13),
                  items: StationsData.availableCities.map((city) {
                    return DropdownMenuItem(value: city, child: Text(city));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCity = val);
                  },
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

          const SizedBox(height: 8),

          // LISTA DE POSTOS
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Nenhum posto encontrado com estes filtros.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.builder(
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

    return Card(
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
                ],
              ),
              const SizedBox(height: 10),
              Text(station.address, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const Divider(color: AppTheme.darkBorder, height: 20),
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
                      const SizedBox(width: 12),
                      Text(
                        '~${station.estimatedPricePerKwh.toStringAsFixed(2)} €/kWh',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryElectric, fontWeight: FontWeight.bold),
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
