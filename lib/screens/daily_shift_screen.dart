import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_shift.dart';
import '../models/vehicle_profile.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class DailyShiftScreen extends StatefulWidget {
  const DailyShiftScreen({super.key});

  @override
  State<DailyShiftScreen> createState() => _DailyShiftScreenState();
}

class _DailyShiftScreenState extends State<DailyShiftScreen> {
  final TextEditingController _earningsController = TextEditingController();
  final TextEditingController _uberController = TextEditingController();
  final TextEditingController _boltController = TextEditingController();
  final TextEditingController _otherEarningsController = TextEditingController();
  final TextEditingController _tipsController = TextEditingController();
  final TextEditingController _startKmController = TextEditingController();
  final TextEditingController _endKmController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _chargingCostController = TextEditingController();
  final TextEditingController _chargingKwhController = TextEditingController();
  final TextEditingController _tollsController = TextEditingController();
  final TextEditingController _otherExpensesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  VehicleProfile _profile = VehicleProfile();
  bool _isLoading = true;

  bool _splitEarningsByPlatform = false;
  bool _enableUber = true;
  bool _enableBolt = true;
  bool _enableTips = true;
  bool _enableOther = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _earningsController.dispose();
    _uberController.dispose();
    _boltController.dispose();
    _otherEarningsController.dispose();
    _tipsController.dispose();
    _startKmController.dispose();
    _endKmController.dispose();
    _kmController.dispose();
    _hoursController.dispose();
    _chargingCostController.dispose();
    _chargingKwhController.dispose();
    _tollsController.dispose();
    _otherExpensesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prof = await StorageService.loadVehicleProfile();
    final prefs = await SharedPreferences.getInstance();
    final todaySession = await StorageService.getDrivingSessionForDate(DateTime.now());
    if (todaySession != null) {
      if (_startKmController.text.isEmpty && (todaySession.startKm ?? 0) > 0) {
        _startKmController.text = todaySession.startKm!.toStringAsFixed(0);
      }
      if (_endKmController.text.isEmpty && (todaySession.endKm ?? 0) > 0) {
        _endKmController.text = todaySession.endKm!.toStringAsFixed(0);
      }
      if (_kmController.text.isEmpty && todaySession.totalKmDriven > 0) {
        _kmController.text = todaySession.totalKmDriven.toStringAsFixed(1);
      }
      if (_hoursController.text.isEmpty && todaySession.totalDrivingSeconds > 0) {
        _hoursController.text = (todaySession.totalDrivingSeconds / 3600.0).toStringAsFixed(1);
      }
    }
    setState(() {
      _profile = prof;
      _splitEarningsByPlatform = prefs.getBool('voltdrive_split_earnings_by_platform') ?? false;
      _enableUber = prefs.getBool('voltdrive_enable_uber') ?? true;
      _enableBolt = prefs.getBool('voltdrive_enable_bolt') ?? true;
      _enableTips = prefs.getBool('voltdrive_enable_tips') ?? true;
      _enableOther = prefs.getBool('voltdrive_enable_other') ?? true;
      _isLoading = false;
    });
  }

  void _updateCalculatedKm() {
    final start = double.tryParse(_startKmController.text.replaceAll(',', '.')) ?? 0.0;
    final end = double.tryParse(_endKmController.text.replaceAll(',', '.')) ?? 0.0;
    if (end > start && start > 0) {
      _kmController.text = (end - start).toStringAsFixed(1);
    }
  }

  void _updatePlatformEarningsSum() {
    double total = 0.0;
    if (_enableUber) {
      total += double.tryParse(_uberController.text.replaceAll(',', '.')) ?? 0.0;
    }
    if (_enableBolt) {
      total += double.tryParse(_boltController.text.replaceAll(',', '.')) ?? 0.0;
    }
    if (_enableOther) {
      total += double.tryParse(_otherEarningsController.text.replaceAll(',', '.')) ?? 0.0;
    }
    _earningsController.text = total > 0 ? total.toStringAsFixed(2) : '';
  }

  DailyShift _calculateCurrentShift() {
    final uber = double.tryParse(_uberController.text.replaceAll(',', '.')) ?? 0.0;
    final bolt = double.tryParse(_boltController.text.replaceAll(',', '.')) ?? 0.0;
    final other = double.tryParse(_otherEarningsController.text.replaceAll(',', '.')) ?? 0.0;
    final manualEarnings = double.tryParse(_earningsController.text.replaceAll(',', '.')) ?? 0.0;
    final earnings = _splitEarningsByPlatform ? (uber + bolt + other) : manualEarnings;

    final tips = double.tryParse(_tipsController.text.replaceAll(',', '.')) ?? 0.0;
    final startKm = double.tryParse(_startKmController.text.replaceAll(',', '.')) ?? 0.0;
    final endKm = double.tryParse(_endKmController.text.replaceAll(',', '.')) ?? 0.0;
    final manualKm = double.tryParse(_kmController.text.replaceAll(',', '.')) ?? 0.0;
    final km = (endKm > startKm && startKm > 0) ? (endKm - startKm) : manualKm;
    final hours = double.tryParse(_hoursController.text.replaceAll(',', '.')) ?? 0.0;
    final charging = double.tryParse(_chargingCostController.text.replaceAll(',', '.')) ?? 0.0;
    final kwh = double.tryParse(_chargingKwhController.text.replaceAll(',', '.')) ?? 0.0;
    final tolls = double.tryParse(_tollsController.text.replaceAll(',', '.')) ?? 0.0;
    final others = double.tryParse(_otherExpensesController.text.replaceAll(',', '.')) ?? 0.0;

    return DailyShift(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      driverEarnings: earnings,
      uberGross: uber,
      boltGross: bolt,
      otherEarnings: other,
      tips: tips,
      startKm: startKm,
      endKm: endKm,
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
      startKm: startKm,
      endKm: endKm,
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
                      _buildMetricItem('Dinheiro Ganho', '${shift.netRevenue.toStringAsFixed(2)} €', AppTheme.textPrimary),
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

            // DINHEIRO GANHO NO TURNO (COM DISCRIMINAÇÃO POR PLATAFORMAS OU SIMPLIFICADO)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _splitEarningsByPlatform ? Icons.business_center_outlined : Icons.payments_outlined,
                              color: AppTheme.accentGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _splitEarningsByPlatform ? 'Ganhos por Empresa / Plataforma' : 'Dinheiro Ganho no Turno',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () async {
                              setState(() => _splitEarningsByPlatform = !_splitEarningsByPlatform);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('voltdrive_split_earnings_by_platform', _splitEarningsByPlatform);
                              _updatePlatformEarningsSum();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _splitEarningsByPlatform ? AppTheme.accentGreen.withOpacity(0.18) : AppTheme.darkSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _splitEarningsByPlatform ? AppTheme.accentGreen : AppTheme.darkBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(_splitEarningsByPlatform ? Icons.tune : Icons.add_circle_outline, size: 13, color: _splitEarningsByPlatform ? AppTheme.accentGreen : AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    _splitEarningsByPlatform ? 'Empresas (Uber/Bolt)' : '+ Uber, Bolt...',
                                    style: TextStyle(
                                      color: _splitEarningsByPlatform ? AppTheme.accentGreen : AppTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                              await _loadProfile();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryElectric.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.settings, size: 14, color: AppTheme.primaryElectric),
                            ),
                          ),
                        ],
                      ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _splitEarningsByPlatform
                          ? 'Insere os valores de cada empresa. A app soma o total automaticamente.'
                          : 'Insere o valor real que fica para ti (já sem comissões)',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    if (_splitEarningsByPlatform) ...[
                      // Resumo Dinâmico com a Soma Automática
                      Builder(builder: (_) {
                        final u = double.tryParse(_uberController.text.replaceAll(',', '.')) ?? 0.0;
                        final b = double.tryParse(_boltController.text.replaceAll(',', '.')) ?? 0.0;
                        final o = double.tryParse(_otherEarningsController.text.replaceAll(',', '.')) ?? 0.0;
                        final t = double.tryParse(_tipsController.text.replaceAll(',', '.')) ?? 0.0;
                        final total = u + b + o + t;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentGreen.withOpacity(0.15),
                                AppTheme.darkCard,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accentGreen.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calculate_outlined, color: AppTheme.accentGreen, size: 20),
                                  SizedBox(width: 8),
                                  Text('Total Faturado no Turno:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                ],
                              ),
                              Text(
                                '${total.toStringAsFixed(2)} €',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.accentGreen),
                              ),
                            ],
                          ),
                        );
                      }),

                      if (_enableUber) ...[
                        TextField(
                          controller: _uberController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Uber (€)',
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.directions_car, color: AppTheme.accentGreen),
                          ),
                          onChanged: (_) {
                            _updatePlatformEarningsSum();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_enableBolt) ...[
                        TextField(
                          controller: _boltController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Bolt (€)',
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.bolt, color: AppTheme.warningAmber),
                          ),
                          onChanged: (_) {
                            _updatePlatformEarningsSum();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_enableOther) ...[
                        TextField(
                          controller: _otherEarningsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Outras / Particulares (€)',
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.receipt_long, color: Colors.tealAccent),
                          ),
                          onChanged: (_) {
                            _updatePlatformEarningsSum();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_enableTips) ...[
                        TextField(
                          controller: _tipsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Gorjetas / Extras (€)',
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.volunteer_activism, color: AppTheme.primaryElectric),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: _earningsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Dinheiro que fica para mim (€)',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accentGreen),
                          helperText: 'Total líquido ganho com as viagens do dia',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tipsController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Gorjetas / Extras (€) (opcional)',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.volunteer_activism, color: AppTheme.primaryElectric),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
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
                    // REGISTO DE ODÓMETRO INICIAL E FINAL
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startKmController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Km Inicial',
                              hintText: 'Ex: 124500',
                              prefixIcon: Icon(Icons.pin_drop_outlined, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) {
                              _updateCalculatedKm();
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _endKmController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Km Final',
                              hintText: 'Ex: 124710',
                              prefixIcon: Icon(Icons.flag_outlined, color: AppTheme.accentGreen),
                            ),
                            onChanged: (_) {
                              _updateCalculatedKm();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _kmController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Km Totais',
                              hintText: '0.0',
                              prefixIcon: Icon(Icons.route, color: AppTheme.primaryElectric),
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
                              labelText: 'Horas (h)',
                              hintText: 'Ex: 8.0',
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
                              hintText: '0.00',
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
                              hintText: '0.0',
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
                              labelText: 'Portagens (€)',
                              hintText: '0.00',
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
                              labelText: 'Outros (€)',
                              hintText: '0.00',
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
                        hintText: 'Ex: Turno calmo, chuva à noite...',
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
