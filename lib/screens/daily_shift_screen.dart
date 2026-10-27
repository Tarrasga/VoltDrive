import 'package:flutter/material.dart';
import '../models/daily_shift.dart';
import '../models/vehicle_profile.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class DailyShiftScreen extends StatefulWidget {
  const DailyShiftScreen({super.key});

  @override
  State<DailyShiftScreen> createState() => _DailyShiftScreenState();
}

class _DailyShiftScreenState extends State<DailyShiftScreen> {
  final TextEditingController _uberController = TextEditingController(text: '95.00');
  final TextEditingController _boltController = TextEditingController(text: '80.00');
  final TextEditingController _tipsController = TextEditingController(text: '8.50');
  final TextEditingController _kmController = TextEditingController(text: '210.0');
  final TextEditingController _hoursController = TextEditingController(text: '8.5');
  final TextEditingController _chargingCostController = TextEditingController(text: '12.50');
  final TextEditingController _chargingKwhController = TextEditingController(text: '34.0');
  final TextEditingController _tollsController = TextEditingController(text: '4.20');
  final TextEditingController _otherExpensesController = TextEditingController(text: '2.50');
  final TextEditingController _notesController = TextEditingController();

  VehicleProfile _profile = VehicleProfile();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prof = await StorageService.loadVehicleProfile();
    setState(() {
      _profile = prof;
      _isLoading = false;
    });
  }

  DailyShift _calculateCurrentShift() {
    final uber = double.tryParse(_uberController.text.replaceAll(',', '.')) ?? 0.0;
    final bolt = double.tryParse(_boltController.text.replaceAll(',', '.')) ?? 0.0;
    final tips = double.tryParse(_tipsController.text.replaceAll(',', '.')) ?? 0.0;
    final km = double.tryParse(_kmController.text.replaceAll(',', '.')) ?? 0.0;
    final hours = double.tryParse(_hoursController.text.replaceAll(',', '.')) ?? 8.0;
    final charging = double.tryParse(_chargingCostController.text.replaceAll(',', '.')) ?? 0.0;
    final kwh = double.tryParse(_chargingKwhController.text.replaceAll(',', '.')) ?? 0.0;
    final tolls = double.tryParse(_tollsController.text.replaceAll(',', '.')) ?? 0.0;
    final others = double.tryParse(_otherExpensesController.text.replaceAll(',', '.')) ?? 0.0;

    return DailyShift(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      uberGross: uber,
      boltGross: bolt,
      tips: tips,
      totalKm: km,
      hoursWorked: hours,
      chargingCost: charging,
      chargingKwh: kwh,
      tollsCost: tolls,
      otherExpenses: others,
      notes: _notesController.text,
      platformFeePercent: _profile.platformFeePercent,
      fleetCommissionPercent: _profile.fleetCommissionPercent,
    );
  }

  Future<void> _saveShift() async {
    final shift = _calculateCurrentShift();
    await StorageService.saveShift(shift);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Turno guardado com sucesso! Lucro Líquido: ${shift.netProfit.toStringAsFixed(2)} €'),
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

    final shift = _calculateCurrentShift();
    final isAboveTarget = shift.netProfit >= _profile.targetDailyProfit;
    final targetDiff = shift.netProfit - _profile.targetDailyProfit;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.query_stats_rounded, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Fecho do Dia TVDE'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CARTÃO DE BALANÇO FINAL DO DIA (Destaque Principal)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAboveTarget ? AppTheme.accentGreen : AppTheme.warningAmber,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isAboveTarget ? AppTheme.accentGreen : AppTheme.warningAmber).withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LUCRO LÍQUIDO DO DIA',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isAboveTarget ? AppTheme.accentGreen : AppTheme.warningAmber).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAboveTarget
                              ? '+${targetDiff.toStringAsFixed(2)}€ acima da meta'
                              : '${targetDiff.toStringAsFixed(2)}€ para a meta',
                          style: TextStyle(
                            color: isAboveTarget ? AppTheme.accentGreen : AppTheme.warningAmber,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${shift.netProfit.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: isAboveTarget ? AppTheme.accentGreen : AppTheme.warningAmber,
                    ),
                  ),
                  const Divider(color: AppTheme.darkBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Faturação Bruta', '${shift.totalGross.toStringAsFixed(2)} €', AppTheme.textPrimary),
                      Container(width: 1, height: 35, color: AppTheme.darkBorder),
                      _buildMetricItem('Despesas Totais', '${shift.totalExpenses.toStringAsFixed(2)} €', AppTheme.dangerRed),
                      Container(width: 1, height: 35, color: AppTheme.darkBorder),
                      _buildMetricItem('Lucro / km', '${shift.profitPerKm.toStringAsFixed(2)} €/km', AppTheme.primaryElectric),
                      Container(width: 1, height: 35, color: AppTheme.darkBorder),
                      _buildMetricItem('Lucro / Hora', '${shift.profitPerHour.toStringAsFixed(1)} €/h', AppTheme.accentGreen),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // FATURAÇÃO (UBER / BOLT / GORJETAS)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payments_outlined, color: AppTheme.accentGreen, size: 20),
                        SizedBox(width: 8),
                        Text('Faturação do Dia (Bruta)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _uberController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Uber Bruto (€)',
                              prefixIcon: Icon(Icons.drive_eta, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _boltController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Bolt Bruto (€)',
                              prefixIcon: Icon(Icons.bolt, color: AppTheme.accentGreen),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tipsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Gorjetas / Tips (€) (100% livres de taxa)',
                        prefixIcon: Icon(Icons.volunteer_activism, color: AppTheme.primaryElectric),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // QUILÓMETROS E TEMPO
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.speed, color: AppTheme.primaryElectric, size: 20),
                        SizedBox(width: 8),
                        Text('Quilómetros e Horas do Turno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _kmController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Km Totais Rodados',
                              prefixIcon: Icon(Icons.route, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _hoursController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Horas Trabalhadas',
                              prefixIcon: Icon(Icons.schedule, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // CUSTOS DO VEÍCULO ELÉTRICO E DESPESAS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.ev_station, color: AppTheme.warningAmber, size: 20),
                        SizedBox(width: 8),
                        Text('Gastos com Carregamento e Operação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chargingCostController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Carregamento (€)',
                              prefixIcon: Icon(Icons.electric_bolt, color: AppTheme.primaryElectric),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _chargingKwhController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Energia (kWh)',
                              prefixIcon: Icon(Icons.battery_charging_full, color: AppTheme.accentGreen),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tollsController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Portagens / Via Verde (€)',
                              prefixIcon: Icon(Icons.toll, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _otherExpensesController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Outros (€) (Lavagem, etc)',
                              prefixIcon: Icon(Icons.receipt_long, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas do Dia (opcional)',
                        prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // BOTÃO DE GUARDAR TURNO
            ElevatedButton.icon(
              onPressed: _saveShift,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar Registo do Dia'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
