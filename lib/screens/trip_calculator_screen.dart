import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_calculation.dart';
import '../models/vehicle_profile.dart';
import '../services/assistant_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class TripCalculatorScreen extends StatefulWidget {
  const TripCalculatorScreen({super.key});

  @override
  State<TripCalculatorScreen> createState() => _TripCalculatorScreenState();
}

class _TripCalculatorScreenState extends State<TripCalculatorScreen> with WidgetsBindingObserver {
  final TextEditingController _fareController = TextEditingController();
  final TextEditingController _pickupDistController = TextEditingController();
  final TextEditingController _tripDistController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _tollsController = TextEditingController();
  final TextEditingController _ratePerKmController = TextEditingController();

  VehicleProfile _profile = VehicleProfile();
  bool _usePublicCharging = true;
  bool _isPrivateTrip = false;
  bool _isLoading = true;
  bool _includeVehicleConsumption = false; // Por defeito: não calcular consumo do carro nas contas
  int _overlayTimeoutSeconds = 12;

  bool _overlayGranted = false;
  bool _accessibilityEnabled = false;
  bool _isReaderPaused = false;
  bool _uberInstalled = false;
  bool _boltInstalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _checkAssistantPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fareController.dispose();
    _pickupDistController.dispose();
    _tripDistController.dispose();
    _durationController.dispose();
    _tollsController.dispose();
    _ratePerKmController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAssistantPermissions();
    }
  }

  Future<void> _checkAssistantPermissions() async {
    final overlay = await AssistantService.isOverlayGranted();
    final a11y = await AssistantService.isAccessibilityEnabled();
    final paused = await AssistantService.isScreenReaderPaused();
    final tvdeStatus = await AssistantService.getTvdeAppsStatus();
    if (mounted) {
      setState(() {
        _overlayGranted = overlay;
        _accessibilityEnabled = a11y;
        _isReaderPaused = paused;
        _uberInstalled = tvdeStatus.uberInstalled;
        _boltInstalled = tvdeStatus.boltInstalled;
      });
    }
  }

  Future<void> _loadProfile() async {
    final prof = await StorageService.loadVehicleProfile();
    await AssistantService.syncSettings(prof);
    final prefs = await SharedPreferences.getInstance();
    final incCons = prefs.getBool('include_vehicle_consumption') ?? false;
    if (mounted) {
      setState(() {
        _profile = prof;
        _includeVehicleConsumption = incCons;
        _isLoading = false;
      });
    }
  }

  Future<void> _setIncludeConsumption(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('include_vehicle_consumption', val);
    setState(() {
      _includeVehicleConsumption = val;
    });
  }

  TripCalculation _calculate() {
    final fare = double.tryParse(_fareController.text.replaceAll(',', '.')) ?? 0.0;
    final pickup = double.tryParse(_pickupDistController.text.replaceAll(',', '.')) ?? 0.0;
    final tripDist = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final duration = double.tryParse(_durationController.text.replaceAll(',', '.')) ?? 15.0;
    final tolls = double.tryParse(_tollsController.text.replaceAll(',', '.')) ?? 0.0;

    final energyCostPerKm = _usePublicCharging
        ? _profile.energyCostPerKmPublic
        : _profile.energyCostPerKmHome;

    final platformRate = _isPrivateTrip ? 0.0 : (_profile.platformFeePercent / 100.0);
    final fleetRate = _isPrivateTrip ? 0.0 : (_profile.fleetCommissionPercent / 100.0);

    return TripCalculation(
      grossFare: fare,
      pickupDistanceKm: pickup,
      tripDistanceKm: tripDist,
      durationMinutes: duration,
      tollsCost: tolls,
      energyCostPerKm: energyCostPerKm,
      platformFeeRate: platformRate,
      fleetFeeRate: fleetRate,
      includeVehicleConsumption: _includeVehicleConsumption,
    );
  }

  void _applyRatePerKm(double rate) {
    final pickup = double.tryParse(_pickupDistController.text.replaceAll(',', '.')) ?? 0.0;
    final tripDist = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final totalDist = pickup + tripDist;
    final calculatedFare = (totalDist > 0 ? totalDist : 10.0) * rate;
    _ratePerKmController.text = rate.toStringAsFixed(2);
    _fareController.text = calculatedFare.toStringAsFixed(2);
    setState(() {});
  }

  void _recalculateFareFromRate() {
    final rate = double.tryParse(_ratePerKmController.text.replaceAll(',', '.')) ?? 0.0;
    final pickup = double.tryParse(_pickupDistController.text.replaceAll(',', '.')) ?? 0.0;
    final tripDist = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final totalDist = pickup + tripDist;
    if (rate > 0 && totalDist > 0) {
      final calculatedFare = totalDist * rate;
      _fareController.text = calculatedFare.toStringAsFixed(2);
      setState(() {});
    }
  }

  void _onFareChanged(String val) {
    final fare = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    final pickup = double.tryParse(_pickupDistController.text.replaceAll(',', '.')) ?? 0.0;
    final trip = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final total = pickup + trip;
    if (total > 0 && fare > 0) {
      _ratePerKmController.text = (fare / total).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _onDistanceChanged() {
    final rate = double.tryParse(_ratePerKmController.text.replaceAll(',', '.')) ?? 0.0;
    final pickup = double.tryParse(_pickupDistController.text.replaceAll(',', '.')) ?? 0.0;
    final trip = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final total = pickup + trip;
    final currentFare = double.tryParse(_fareController.text.replaceAll(',', '.')) ?? 0.0;
    // Se já tiver valor da viagem calculado, não voltar a calcular por cima
    if (rate > 0 && total > 0 && currentFare <= 0) {
      _fareController.text = (total * rate).toStringAsFixed(2);
    } else if (total > 0 && currentFare > 0) {
      _ratePerKmController.text = (currentFare / total).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _adjustFare(double delta) {
    final current = double.tryParse(_fareController.text.replaceAll(',', '.')) ?? 0.0;
    final next = (current + delta).clamp(0.0, 999.0);
    _fareController.text = next.toStringAsFixed(2);
    final pickup = double.tryParse(_pickupDistController.text.replaceAll(',', '.')) ?? 0.0;
    final trip = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final total = pickup + trip;
    if (total > 0) {
      _ratePerKmController.text = (next / total).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _adjustTrip(double delta) {
    final current = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final next = (current + delta).clamp(0.0, 999.0);
    _tripDistController.text = next.toStringAsFixed(1);
    final currentFare = double.tryParse(_fareController.text.replaceAll(',', '.')) ?? 0.0;
    final pickup = double.tryParse(_pickupDistController.text.replaceAll(',', '.')) ?? 0.0;
    final total = pickup + next;
    if (total > 0 && currentFare > 0) {
      _ratePerKmController.text = (currentFare / total).toStringAsFixed(2);
    }
    setState(() {});
  }

  Color _getVerdictColor(ProfitabilityVerdict verdict) {
    switch (verdict) {
      case ProfitabilityVerdict.excelente:
        return AppTheme.accentGreen;
      case ProfitabilityVerdict.aceitavel:
        return AppTheme.warningAmber;
      case ProfitabilityVerdict.fraca:
        return const Color(0xFFFF9100);
      case ProfitabilityVerdict.prejuizo:
        return AppTheme.dangerRed;
    }
  }

  IconData _getVerdictIcon(ProfitabilityVerdict verdict) {
    switch (verdict) {
      case ProfitabilityVerdict.excelente:
        return Icons.check_circle_rounded;
      case ProfitabilityVerdict.aceitavel:
        return Icons.thumb_up_rounded;
      case ProfitabilityVerdict.fraca:
        return Icons.warning_amber_rounded;
      case ProfitabilityVerdict.prejuizo:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryElectric)),
      );
    }

    final calc = _calculate();
    final bool isEmptyState = calc.grossFare <= 0 && calc.totalDistanceKm <= 0;
    final verdictColor = isEmptyState ? AppTheme.primaryElectric : _getVerdictColor(calc.verdict);
    final verdictIcon = isEmptyState ? Icons.calculate_outlined : _getVerdictIcon(calc.verdict);
    final verdictText = isEmptyState ? 'Aguardar Valores' : calc.verdictText;
    final isAssistantActive = _overlayGranted && _accessibilityEnabled && !_isReaderPaused;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Simulador de Viagem TVDE'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFloatingAssistantCard(isAssistantActive),
                        const SizedBox(height: 14),
                        _buildVerdictSummaryCard(calc, isEmptyState, verdictColor, verdictIcon, verdictText),
                        const SizedBox(height: 14),
                        _buildChargingAndConsumptionCard(calc),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInputsCard(calc),
                        const SizedBox(height: 12),
                        _buildDriverTipCard(),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFloatingAssistantCard(isAssistantActive),
                  const SizedBox(height: 16),
                  _buildVerdictSummaryCard(calc, isEmptyState, verdictColor, verdictIcon, verdictText),
                  const SizedBox(height: 16),
                  _buildChargingAndConsumptionCard(calc),
                  const SizedBox(height: 16),
                  _buildInputsCard(calc),
                  const SizedBox(height: 12),
                  _buildDriverTipCard(),
                ],
              ),
      ),
    );
  }

  Widget _buildVerdictSummaryCard(
    TripCalculation calc,
    bool isEmptyState,
    Color verdictColor,
    IconData verdictIcon,
    String verdictText,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: verdictColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: verdictColor.withOpacity(0.2),
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
              Row(
                children: [
                  Icon(verdictIcon, color: verdictColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    verdictText,
                    style: TextStyle(
                      color: verdictColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: verdictColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isEmptyState ? '0.00 € / km' : '${calc.netProfitPerKm.toStringAsFixed(2)} € / km',
                  style: TextStyle(
                    color: verdictColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn(
                label: 'Lucro Líquido',
                value: '${calc.netProfit.toStringAsFixed(2)} €',
                color: verdictColor,
                isLarge: true,
              ),
              Container(width: 1, height: 45, color: AppTheme.darkBorder),
              _buildMetricColumn(
                label: _includeVehicleConsumption ? 'Custo Energia' : 'Valor Faturado',
                value: _includeVehicleConsumption
                    ? '${calc.totalEnergyCost.toStringAsFixed(2)} €'
                    : '${calc.grossFare.toStringAsFixed(2)} €',
                color: AppTheme.primaryElectric,
              ),
              Container(width: 1, height: 45, color: AppTheme.darkBorder),
              _buildMetricColumn(
                label: 'Ritmo / Hora',
                value: '${calc.netProfitPerHour.toStringAsFixed(1)} €/h',
                color: AppTheme.textPrimary,
              ),
            ],
          ),
          const Divider(color: AppTheme.darkBorder, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${calc.totalDistanceKm.toStringAsFixed(1)} km (${calc.pickupDistanceKm.toStringAsFixed(1)} rec. + ${calc.tripDistanceKm.toStringAsFixed(1)} viag.)',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              Text(
                _includeVehicleConsumption
                    ? 'Gasto: ${(calc.totalDistanceKm * (_profile.avgConsumptionKwh100 / 100.0)).toStringAsFixed(1)} kWh'
                    : '⚡ Sem dedução de consumo',
                style: TextStyle(
                  color: _includeVehicleConsumption ? AppTheme.primaryElectric : AppTheme.accentGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargingAndConsumptionCard(TripCalculation calc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Calcular Consumo do Carro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _includeVehicleConsumption
                  ? 'A descontar ${(calc.totalDistanceKm * _profile.energyCostPerKmPublic).toStringAsFixed(2)}€ de energia no lucro'
                  : 'Desativado: nas contas o lucro não desconta o consumo do carro',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            value: _includeVehicleConsumption,
            activeColor: AppTheme.accentGreen,
            onChanged: (val) => _setIncludeConsumption(val),
          ),
          if (_includeVehicleConsumption) ...[
            const Divider(color: AppTheme.darkBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tarifário Carregamento:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('Posto (${_profile.publicKwhPrice.toStringAsFixed(2)}€)'),
                      selected: _usePublicCharging,
                      selectedColor: AppTheme.primaryElectric.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _usePublicCharging ? AppTheme.primaryElectric : AppTheme.textMuted,
                        fontSize: 11,
                      ),
                      onSelected: (val) => setState(() => _usePublicCharging = true),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text('Casa (${_profile.homeKwhPrice.toStringAsFixed(2)}€)'),
                      selected: !_usePublicCharging,
                      selectedColor: AppTheme.accentGreen.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: !_usePublicCharging ? AppTheme.accentGreen : AppTheme.textMuted,
                        fontSize: 11,
                      ),
                      onSelected: (val) => setState(() => _usePublicCharging = false),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverTipCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primaryElectric, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Retenção da app: ${_profile.platformFeePercent.toStringAsFixed(0)}% | Consumo Zoe: ${_profile.avgConsumptionKwh100} kWh/100km. Podes personalizar estes valores no separador Definições.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsCard(TripCalculation calc) {
    return Card(
      child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dados da Corrida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        // Seletor Viagem TVDE vs Particular
                        GestureDetector(
                          onTap: () => setState(() => _isPrivateTrip = !_isPrivateTrip),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isPrivateTrip ? AppTheme.accentGreen.withOpacity(0.18) : AppTheme.darkSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isPrivateTrip ? AppTheme.accentGreen : AppTheme.darkBorder,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPrivateTrip ? Icons.person_rounded : Icons.local_taxi_rounded,
                                  size: 14,
                                  color: _isPrivateTrip ? AppTheme.accentGreen : AppTheme.primaryElectric,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isPrivateTrip ? 'Particular (0% Taxas)' : 'TVDE (${_profile.platformFeePercent.toStringAsFixed(0)}% Taxas)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isPrivateTrip ? AppTheme.accentGreen : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // NOVO BLOCO: CALCULAR VALOR ATRAVÉS DA DISTÂNCIA E VALOR POR KM
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D31),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calculate_outlined, color: AppTheme.primaryElectric, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Calcular Valor através de Distância × €/km',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Toca numa taxa rápida ou escreve o valor por km para calcular o valor total:',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 10),

                          // CHIPS RÁPIDOS DE TAXA POR KM
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [0.80, 1.00, 1.20, 1.50, 2.00].map((rate) {
                              final isSelected = (double.tryParse(_ratePerKmController.text.replaceAll(',', '.')) ?? 0.0) == rate;
                              return ActionChip(
                                label: Text('${rate.toStringAsFixed(2)} €/km'),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                backgroundColor: isSelected ? AppTheme.primaryElectric : AppTheme.darkSurface,
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primaryElectric : AppTheme.darkBorder,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                onPressed: () => _applyRatePerKm(rate),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 10),

                          // INPUT DE €/KM PERSONALIZADO E DISPLAY DA FÓRMULA
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: _ratePerKmController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Taxa / km (€)',
                                    hintText: 'Ex: 0.85',
                                    labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    prefixIcon: const Icon(Icons.speed, size: 16, color: AppTheme.primaryElectric),
                                    filled: true,
                                    fillColor: AppTheme.darkSurface,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                  onChanged: (_) => _recalculateFareFromRate(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Cálculo Direto:', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                      Text(
                                        '${calc.totalDistanceKm.toStringAsFixed(1)} km × ${_ratePerKmController.text} €/km',
                                        style: const TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // VALOR BRUTO PROPOSTO NA APP (€)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fareController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryElectric),
                            decoration: const InputDecoration(
                              labelText: 'Valor Total da Viagem (€)',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.euro, color: AppTheme.primaryElectric),
                            ),
                            onChanged: _onFareChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQuickButton('+1€', () => _adjustFare(1.0)),
                        const SizedBox(width: 6),
                        _buildQuickButton('+5€', () => _adjustFare(5.0)),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // KM ATÉ RECOLHA & KM DA VIAGEM
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pickupDistController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Até Recolha (km)',
                              hintText: '0.0',
                              prefixIcon: Icon(Icons.near_me_outlined, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => _onDistanceChanged(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _tripDistController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Viagem (km)',
                              hintText: '0.0',
                              prefixIcon: Icon(Icons.directions_car_outlined, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => _onDistanceChanged(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Ajuste Viagem: ', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        _buildQuickButton('+2km', () => _adjustTrip(2.0)),
                        const SizedBox(width: 6),
                        _buildQuickButton('+5km', () => _adjustTrip(5.0)),
                        const SizedBox(width: 6),
                        _buildQuickButton('+10km', () => _adjustTrip(10.0)),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // TEMPO ESTIMADO & PORTAGENS
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tempo (minutos)',
                              hintText: 'Ex: 15',
                              prefixIcon: Icon(Icons.timer_outlined, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _tollsController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Portagens (€)',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.toll_outlined, color: AppTheme.textMuted),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAssistantCard(bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.accentGreen.withOpacity(0.08)
            : AppTheme.primaryElectric.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.accentGreen : AppTheme.primaryElectric.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: isActive ? AppTheme.accentGreen : AppTheme.primaryElectric,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Assistente TVDE Zoe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (!(_overlayGranted && _accessibilityEnabled)
                          ? AppTheme.warningAmber
                          : (_isReaderPaused ? Colors.redAccent : AppTheme.accentGreen))
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !(_overlayGranted && _accessibilityEnabled)
                          ? Icons.warning_amber_rounded
                          : (_isReaderPaused ? Icons.pause_circle_filled : Icons.check_circle),
                      color: !(_overlayGranted && _accessibilityEnabled)
                          ? AppTheme.warningAmber
                          : (_isReaderPaused ? Colors.redAccent : AppTheme.accentGreen),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      !(_overlayGranted && _accessibilityEnabled)
                          ? 'CONFIGURAR'
                          : (_isReaderPaused ? 'LEITOR PARADO' : '100% PRONTO'),
                      style: TextStyle(
                        color: !(_overlayGranted && _accessibilityEnabled)
                            ? AppTheme.warningAmber
                            : (_isReaderPaused ? Colors.redAccent : AppTheme.accentGreen),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Lê as ofertas que caem na Uber Driver e Bolt Driver e desenha no topo do ecrã o lucro líquido limpo e €/km para o Renault Zoe.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // INDICADOR DE APPS TVDE DETETADAS NO TELEMÓVEL
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_android, size: 16, color: AppTheme.primaryElectric),
                    SizedBox(width: 6),
                    Text(
                      'Aplicações TVDE no Telemóvel:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // UBER DRIVER
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _uberInstalled ? const Color(0xFF0F2618) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _uberInstalled ? AppTheme.accentGreen.withOpacity(0.4) : AppTheme.darkBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _uberInstalled ? Icons.check_circle : Icons.cancel_outlined,
                              color: _uberInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Uber Driver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(
                                    _uberInstalled ? 'Detetada e Pronta' : 'Não Encontrada',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _uberInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // BOLT DRIVER
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _boltInstalled ? const Color(0xFF0F2618) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _boltInstalled ? AppTheme.accentGreen.withOpacity(0.4) : AppTheme.darkBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _boltInstalled ? Icons.check_circle : Icons.cancel_outlined,
                              color: _boltInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Bolt Driver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(
                                    _boltInstalled ? 'Detetada e Pronta' : 'Não Encontrada',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _boltInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Passo 1: Janela Flutuante ("Aparecer em cima")
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _overlayGranted ? AppTheme.accentGreen.withOpacity(0.4) : AppTheme.darkBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _overlayGranted ? Icons.check_circle : Icons.layers_outlined,
                  color: _overlayGranted ? AppTheme.accentGreen : AppTheme.primaryElectric,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Janela Flutuante',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        _overlayGranted ? 'Permissão concedida' : 'Obrigatório: "Aparecer em cima"',
                        style: TextStyle(
                          color: _overlayGranted ? AppTheme.accentGreen : AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_overlayGranted)
                  ElevatedButton(
                    onPressed: () async {
                      await AssistantService.requestOverlayPermission();
                      _checkAssistantPermissions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryElectric,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Ativar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                else
                  const Icon(Icons.done_all, color: AppTheme.accentGreen, size: 20),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Passo 2: Leitor de Ecrã (Acessibilidade)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isReaderPaused
                  ? const Color(0xFF2A1515)
                  : (_accessibilityEnabled ? const Color(0xFF0F2618) : AppTheme.darkSurface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isReaderPaused
                    ? Colors.redAccent.withOpacity(0.5)
                    : (_accessibilityEnabled ? AppTheme.accentGreen.withOpacity(0.5) : AppTheme.darkBorder),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isReaderPaused
                      ? Icons.pause_circle_filled
                      : (_accessibilityEnabled ? Icons.check_circle : Icons.visibility_outlined),
                  color: _isReaderPaused
                      ? Colors.amber
                      : (_accessibilityEnabled ? AppTheme.accentGreen : AppTheme.warningAmber),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Leitor Uber & Bolt',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        !_accessibilityEnabled
                            ? 'Acessibilidade > "VoltDrive"'
                            : (_isReaderPaused
                                ? 'Leitor PARADO (Não lê o ecrã)'
                                : 'Leitor ATIVO e a escutar pedidos'),
                        style: TextStyle(
                          color: !_accessibilityEnabled
                              ? AppTheme.textMuted
                              : (_isReaderPaused ? Colors.amber : AppTheme.accentGreen),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_accessibilityEnabled)
                  ElevatedButton(
                    onPressed: () async {
                      await AssistantService.requestAccessibilityPermission();
                      _checkAssistantPermissions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningAmber,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Ligar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () async {
                      final newPaused = !_isReaderPaused;
                      await AssistantService.setScreenReaderPaused(newPaused);
                      setState(() => _isReaderPaused = newPaused);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newPaused
                                ? '⏹️ Leitor parado! O VoltDrive não irá ler o ecrã.'
                                : '▶️ Leitor ativado! A escutar ofertas na Uber e Bolt.',
                          ),
                          backgroundColor: newPaused ? Colors.redAccent : AppTheme.accentGreen,
                        ),
                      );
                    },
                    icon: Icon(
                      _isReaderPaused ? Icons.play_arrow : Icons.stop,
                      color: _isReaderPaused ? Colors.black : Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      _isReaderPaused ? 'Ativar' : 'Parar',
                      style: TextStyle(
                        color: _isReaderPaused ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReaderPaused ? AppTheme.accentGreen : const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
              ],
            ),
          ),

          // BOTÃO PRINCIPAL DE PARAR / ATIVAR LEITURA DE ECRÃ
          if (_accessibilityEnabled) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final newPaused = !_isReaderPaused;
                  await AssistantService.setScreenReaderPaused(newPaused);
                  setState(() => _isReaderPaused = newPaused);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newPaused
                            ? '⏹️ Leitor parado. Nenhuma janela irá aparecer sobre o ecrã.'
                            : '▶️ Leitor de ecrã ativo e pronto para ler viagens!',
                      ),
                      backgroundColor: newPaused ? Colors.redAccent : AppTheme.accentGreen,
                    ),
                  );
                },
                icon: Icon(
                  _isReaderPaused ? Icons.play_circle_fill : Icons.stop_circle,
                  color: _isReaderPaused ? Colors.black : Colors.white,
                  size: 20,
                ),
                label: Text(
                  _isReaderPaused ? 'ATIVAR LEITURA DO ECRÃ' : 'PARAR DE LER O ECRÃ',
                  style: TextStyle(
                    color: _isReaderPaused ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isReaderPaused ? AppTheme.accentGreen : const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Aviso Samsung Galaxy / Definições Restritas
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryElectric, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No Samsung diz "Definição restrita"?',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: _showPermissionHelpDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Ver Ajuda ➔', style: TextStyle(color: AppTheme.primaryElectric, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Configuração de Tempo & Filtro Anti-Falsos
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentGreen.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duração do Cartão no Ecrã:', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    Row(
                      children: [8, 10, 12, 15].map((sec) {
                        final isSel = _overlayTimeoutSeconds == sec;
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() => _overlayTimeoutSeconds = sec);
                              AssistantService.syncOverlayTimeout(sec);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.accentGreen : AppTheme.darkSurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${sec}s',
                                style: TextStyle(
                                  color: isSel ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '🛡️ Filtro Anti-Falso: A janela só abre com pedidos reais (Aceitar). O ecrã inicial de ganhos diários é ignorado.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
                const SizedBox(height: 2),
                const Text(
                  '✕ O botão Fechar fecha o cartão de imediato sem nunca abrir a app.',
                  style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Botão de Teste da Janela Flutuante
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final granted = await AssistantService.isOverlayGranted();
                if (!granted) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Primeiro autoriza a Janela Flutuante ("Aparecer em cima") no Passo 1.'),
                        backgroundColor: AppTheme.warningAmber,
                      ),
                    );
                  }
                  await AssistantService.requestOverlayPermission();
                  return;
                }

                final shown = await AssistantService.showTestOffer();
                if (shown && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚡ Janela flutuante disparada no topo do ecrã!'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                } else if (mounted) {
                  _showSimulatedFloatingOfferDialog();
                }
              },
              icon: const Icon(Icons.play_circle_outline, color: Colors.black, size: 18),
              label: const Text(
                '⚡ Testar Janela Flutuante no Ecrã Agora',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppTheme.primaryElectric, size: 24),
            SizedBox(width: 8),
            Text('Ativar Assistente TVDE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para o assistente ler a Bolt/Uber e desenhar o lucro no ecrã:',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1️⃣ Janela Flutuante ("Aparecer em cima"):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryElectric)),
                    SizedBox(height: 4),
                    Text('Toca em "1. Ativar Janela", procura VoltDrive e liga o interruptor.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('2️⃣ Leitor de Viagens Bolt / Uber:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                    SizedBox(height: 4),
                    Text('Toca em "2. Ativar Leitor" ➔ Aplicações Instaladas ➔ ativa "VoltDrive - Leitor TVDE".', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ Diz "Definição restrita" no Samsung / Android 14?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.warningAmber)),
                    SizedBox(height: 4),
                    Text('1. Clica no botão "Abrir Definições do VoltDrive" abaixo.\n2. Toca nos 3 pontinhos (⋮) no canto superior direito.\n3. Escolhe "Permitir definições restritas".\n4. Volta aqui e já podes ativar o Leitor!', style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AssistantService.requestAccessibilityPermission();
            },
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.accentGreen)),
            child: const Text('Acessibilidade', style: TextStyle(color: AppTheme.accentGreen)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AssistantService.openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryElectric),
            child: const Text('Definições VoltDrive', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSimulatedFloatingOfferDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171B26),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.accentGreen, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF00D665), borderRadius: BorderRadius.circular(6)),
                        child: const Text('BOLT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      const Text('⚡ VoltDrive • Renault Zoe', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+6.00 €', style: TextStyle(color: AppTheme.accentGreen, fontSize: 28, fontWeight: FontWeight.bold)),
                      Text('LUCRO LÍQUIDO LIMPO', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('0.65 €/km', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.accentGreen, borderRadius: BorderRadius.circular(6)),
                        child: const Text('BOM NEGÓCIO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Color(0xFF2E384D), height: 20),
              const Text('Bruto: 8.50 €  |  Distância: 9.2 km  |  Custo Zoe: -0.38 €', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 12),
              const Text(
                '💡 É exatamente assim que a janela surge sobre a Bolt Driver quando recebes uma corrida!',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Dispensar', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await AssistantService.requestOverlayPermission();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
                    child: const Text('Ativar Janela no Ecrã', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color color,
    bool isLarge = false,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isLarge ? 22 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: const BorderSide(color: AppTheme.darkBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AppTheme.darkSurface,
        ),
        child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
