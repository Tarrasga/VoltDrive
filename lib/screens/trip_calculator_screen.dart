import 'package:flutter/material.dart';
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
  final TextEditingController _fareController = TextEditingController(text: '8.50');
  final TextEditingController _pickupDistController = TextEditingController(text: '2.5');
  final TextEditingController _tripDistController = TextEditingController(text: '9.0');
  final TextEditingController _durationController = TextEditingController(text: '20');
  final TextEditingController _tollsController = TextEditingController(text: '0.00');

  VehicleProfile _profile = VehicleProfile();
  bool _usePublicCharging = true;
  bool _isLoading = true;

  bool _overlayGranted = false;
  bool _accessibilityEnabled = false;

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
    if (mounted) {
      setState(() {
        _overlayGranted = overlay;
        _accessibilityEnabled = a11y;
      });
    }
  }

  Future<void> _loadProfile() async {
    final prof = await StorageService.loadVehicleProfile();
    await AssistantService.syncSettings(prof);
    if (mounted) {
      setState(() {
        _profile = prof;
        _isLoading = false;
      });
    }
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

    return TripCalculation(
      grossFare: fare,
      pickupDistanceKm: pickup,
      tripDistanceKm: tripDist,
      durationMinutes: duration,
      tollsCost: tolls,
      energyCostPerKm: energyCostPerKm,
      platformFeeRate: _profile.platformFeePercent / 100.0,
      fleetFeeRate: _profile.fleetCommissionPercent / 100.0,
    );
  }

  void _adjustFare(double delta) {
    final current = double.tryParse(_fareController.text.replaceAll(',', '.')) ?? 0.0;
    final next = (current + delta).clamp(0.0, 999.0);
    _fareController.text = next.toStringAsFixed(2);
    setState(() {});
  }

  void _adjustTrip(double delta) {
    final current = double.tryParse(_tripDistController.text.replaceAll(',', '.')) ?? 0.0;
    final next = (current + delta).clamp(0.0, 999.0);
    _tripDistController.text = next.toStringAsFixed(1);
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
    final verdictColor = _getVerdictColor(calc.verdict);
    final isAssistantActive = _overlayGranted && _accessibilityEnabled;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CARTÃO DO ASSISTENTE FLUTUANTE (LEITOR AUTOMÁTICO UBER & BOLT)
            _buildFloatingAssistantCard(isAssistantActive),

            const SizedBox(height: 16),

            // CARTÃO DE RESULTADO E VEREDITO (Topo em Destaque)
            Container(
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
                          Icon(_getVerdictIcon(calc.verdict), color: verdictColor, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            calc.verdictText,
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
                          '${calc.netProfitPerKm.toStringAsFixed(2)} € / km',
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
                        label: 'Custo Energia',
                        value: '${calc.totalEnergyCost.toStringAsFixed(2)} €',
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
                        'Total: ${calc.totalDistanceKm.toStringAsFixed(1)} km (${calc.pickupDistanceKm.toStringAsFixed(1)} recolha + ${calc.tripDistanceKm.toStringAsFixed(1)} viagem)',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      Text(
                        'Gasto: ${(calc.totalDistanceKm * (_profile.avgConsumptionKwh100 / 100.0)).toStringAsFixed(1)} kWh',
                        style: const TextStyle(color: AppTheme.primaryElectric, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // SELETOR RÁPIDO DO TIPO DE CARREGAMENTO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Preço Carregamento:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text('Posto (${_profile.publicKwhPrice.toStringAsFixed(2)}€)'),
                        selected: _usePublicCharging,
                        selectedColor: AppTheme.primaryElectric.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _usePublicCharging ? AppTheme.primaryElectric : AppTheme.textMuted,
                          fontSize: 12,
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
                          fontSize: 12,
                        ),
                        onSelected: (val) => setState(() => _usePublicCharging = false),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // INPUTS RÁPIDOS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dados da Corrida Manual (ou Simulada)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                              labelText: 'Valor Proposto (€)',
                              prefixIcon: Icon(Icons.euro, color: AppTheme.primaryElectric),
                            ),
                            onChanged: (_) => setState(() {}),
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
                              prefixIcon: Icon(Icons.near_me_outlined, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _tripDistController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Viagem (km)',
                              prefixIcon: Icon(Icons.directions_car_outlined, color: AppTheme.textMuted),
                            ),
                            onChanged: (_) => setState(() {}),
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

            const SizedBox(height: 12),

            // DICA PARA O CONDUTOR
            Container(
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
                  color: (isActive ? AppTheme.accentGreen : AppTheme.warningAmber).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isActive ? AppTheme.accentGreen : AppTheme.warningAmber,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? '100% PRONTO' : 'CONFIGURAR',
                      style: TextStyle(
                        color: isActive ? AppTheme.accentGreen : AppTheme.warningAmber,
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
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _accessibilityEnabled ? AppTheme.accentGreen.withOpacity(0.4) : AppTheme.darkBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _accessibilityEnabled ? Icons.check_circle : Icons.visibility_outlined,
                  color: _accessibilityEnabled ? AppTheme.accentGreen : AppTheme.warningAmber,
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
                        _accessibilityEnabled ? 'Leitor ativo e a escutar' : 'Acessibilidade > "VoltDrive"',
                        style: TextStyle(
                          color: _accessibilityEnabled ? AppTheme.accentGreen : AppTheme.textMuted,
                          fontSize: 11,
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
                  const Icon(Icons.done_all, color: AppTheme.accentGreen, size: 20),
              ],
            ),
          ),

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
