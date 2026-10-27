import 'package:flutter/material.dart';
import '../models/vehicle_profile.dart';
import '../services/assistant_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _batteryController = TextEditingController();
  final TextEditingController _consumptionController = TextEditingController();
  final TextEditingController _homeKwhController = TextEditingController();
  final TextEditingController _publicKwhController = TextEditingController();
  final TextEditingController _platformFeeController = TextEditingController();
  final TextEditingController _fleetFeeController = TextEditingController();
  final TextEditingController _targetProfitController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await StorageService.loadVehicleProfile();
    setState(() {
      _nameController.text = profile.name;
      _batteryController.text = profile.batteryCapacityKwh.toString();
      _consumptionController.text = profile.avgConsumptionKwh100.toString();
      _homeKwhController.text = profile.homeKwhPrice.toString();
      _publicKwhController.text = profile.publicKwhPrice.toString();
      _platformFeeController.text = profile.platformFeePercent.toString();
      _fleetFeeController.text = profile.fleetCommissionPercent.toString();
      _targetProfitController.text = profile.targetDailyProfit.toString();
      _isLoading = false;
    });
  }

  void _applyVehiclePreset(String name, double battery, double consumption) {
    setState(() {
      _nameController.text = name;
      _batteryController.text = battery.toString();
      _consumptionController.text = consumption.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Valores de $name aplicados!'), backgroundColor: AppTheme.primaryElectric),
    );
  }

  Future<void> _save() async {
    final profile = VehicleProfile(
      name: _nameController.text.trim().isEmpty ? 'Renault Zoe Z.E. 50' : _nameController.text.trim(),
      batteryCapacityKwh: double.tryParse(_batteryController.text.replaceAll(',', '.')) ?? 52.0,
      avgConsumptionKwh100: double.tryParse(_consumptionController.text.replaceAll(',', '.')) ?? 18.6,
      homeKwhPrice: double.tryParse(_homeKwhController.text.replaceAll(',', '.')) ?? 0.16,
      publicKwhPrice: double.tryParse(_publicKwhController.text.replaceAll(',', '.')) ?? 0.32,
      platformFeePercent: double.tryParse(_platformFeeController.text.replaceAll(',', '.')) ?? 25.0,
      fleetCommissionPercent: double.tryParse(_fleetFeeController.text.replaceAll(',', '.')) ?? 0.0,
      targetDailyProfit: double.tryParse(_targetProfitController.text.replaceAll(',', '.')) ?? 120.0,
    );

    await StorageService.saveVehicleProfile(profile);
    await AssistantService.syncSettings(profile);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configurações guardadas com sucesso!'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryElectric)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_outlined, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Definições do Veículo & Custos'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PRESETS RÁPIDOS DE CARROS TVDE ELÉTRICOS (Com destaque no Renault Zoe)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Modelos Comuns TVDE (Toque para aplicar)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryElectric)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip('Renault Zoe Z.E. 50 (22kW AC)', 52.0, 18.6, isHighlight: true),
                        _buildPresetChip('Tesla Model 3', 60.0, 14.5),
                        _buildPresetChip('MG4 EV', 51.0, 15.8),
                        _buildPresetChip('BYD Atto 3', 60.5, 16.0),
                        _buildPresetChip('Kia Niro EV', 64.0, 15.5),
                        _buildPresetChip('Nissan Leaf', 40.0, 16.5),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // DADOS DO VEÍCULO
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_car, color: AppTheme.primaryElectric, size: 20),
                        SizedBox(width: 8),
                        Text('O Teu Carro Elétrico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome / Modelo da Viatura',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _batteryController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Capacidade (kWh)',
                              helperText: 'Ex: 52 kWh no Zoe',
                              prefixIcon: Icon(Icons.battery_5_bar, color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _consumptionController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Consumo Médio (kWh/100km)',
                              helperText: 'Ex: 18.6 kWh/100km',
                              prefixIcon: Icon(Icons.speed, color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // PREÇOS DA ELETRICIDADE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.electric_bolt, color: AppTheme.warningAmber, size: 20),
                        SizedBox(width: 8),
                        Text('Tarifas de Eletricidade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _homeKwhController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Em Casa (€/kWh)',
                              prefixIcon: Icon(Icons.home_outlined, color: AppTheme.accentGreen),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _publicKwhController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Posto Público (€/kWh)',
                              prefixIcon: Icon(Icons.ev_station, color: AppTheme.warningAmber),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // TAXAS E METAS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.percent, color: AppTheme.primaryElectric, size: 20),
                        SizedBox(width: 8),
                        Text('Comissões e Meta Diária', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _platformFeeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Taxa Apps (%)',
                              prefixIcon: Icon(Icons.pie_chart_outline, color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _fleetFeeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Comissão Parceiro (%)',
                              helperText: '0% se carro próprio',
                              prefixIcon: Icon(Icons.handshake_outlined, color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetProfitController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Meta de Lucro Líquido Diário (€)',
                        prefixIcon: Icon(Icons.flag_outlined, color: AppTheme.accentGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Guardar Definições'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String name, double battery, double consumption, {bool isHighlight = false}) {
    return ActionChip(
      label: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          color: isHighlight ? AppTheme.primaryElectric : AppTheme.textPrimary,
        ),
      ),
      backgroundColor: isHighlight ? AppTheme.primaryElectric.withOpacity(0.15) : AppTheme.darkSurface,
      side: BorderSide(color: isHighlight ? AppTheme.primaryElectric : AppTheme.darkBorder),
      onPressed: () => _applyVehiclePreset(name, battery, consumption),
    );
  }
}
