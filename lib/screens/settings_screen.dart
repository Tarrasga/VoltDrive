import 'package:flutter/material.dart';
import '../models/vehicle_profile.dart';
import '../models/financial_goals.dart';
import '../services/assistant_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'financial_goals_screen.dart';
import 'safety_buddies_screen.dart';

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

            const SizedBox(height: 18),

            // METAS & RITMO DIÁRIO TVDE
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.track_changes_rounded, color: AppTheme.accentGreen),
                ),
                title: const Text('Metas Semanais & Mensais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Calcula a meta diária necessária dividindo pelos dias que faltam para fechar o mês', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                onTap: () {
                  FinancialGoalsScreen.showAsModal(context);
                },
              ),
            ),

            const SizedBox(height: 12),

            // PROTEÇÃO DA APLICAÇÃO (LOGIN COM PASS LIGADO AO EMAIL)
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
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryElectric.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryElectric, size: 20),
                            ),
                            const SizedBox(width: 8),
                            const Text('Bloqueio & Palavra-passe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Switch(
                          value: AuthService.isLockEnabled,
                          activeColor: AppTheme.accentGreen,
                          onChanged: (val) => _handleLockToggle(val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AuthService.hasCredentials
                          ? 'Email associado: ${AuthService.userEmail}'
                          : 'Configura o teu email e palavra-passe para proteger os teus dados de lucros e viagens.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showAuthSetupDialog,
                            icon: const Icon(Icons.password, size: 16, color: AppTheme.primaryElectric),
                            label: Text(
                              AuthService.hasCredentials ? 'Alterar Acesso' : 'Configurar Acesso',
                              style: const TextStyle(color: AppTheme.primaryElectric, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.darkBorder)),
                          ),
                        ),
                        if (AuthService.isLockEnabled && AuthService.hasCredentials) ...[
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              AuthService.lockApp();
                            },
                            icon: const Icon(Icons.lock_clock, size: 16, color: Colors.black),
                            label: const Text('Bloquear Agora', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // REDE DE SEGURANÇA E COLEGAS
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppTheme.dangerRed),
                ),
                title: const Text('Rede de Colegas & Botão SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Partilha de localização em tempo real e alerta de emergência', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyBuddiesScreen()));
                },
              ),
            ),

            const SizedBox(height: 12),

            // VERIFICAÇÃO DE ATUALIZAÇÕES
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.system_update_rounded, color: AppTheme.primaryElectric, size: 20),
                            SizedBox(width: 8),
                            Text('Atualizações da Aplicação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: Text('v${UpdateService.currentVersion}', style: const TextStyle(color: AppTheme.primaryElectric, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'O VoltDrive verifica automaticamente no GitHub se existe uma nova versão com novas funções.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('A verificar atualizações no GitHub...')),
                          );
                          final update = await UpdateService.checkForUpdate();
                          if (context.mounted && update != null) {
                            UpdateService.showUpdateDialog(context, update, manualCheck: true);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Não foi possível verificar no momento.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryElectric),
                        label: const Text('Procurar Atualizações Agora', style: TextStyle(color: AppTheme.primaryElectric, fontSize: 12)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.darkBorder)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleLockToggle(bool enable) async {
    if (!AuthService.hasCredentials) {
      _showAuthSetupDialog();
      return;
    }

    if (!enable) {
      // Pedir confirmação da palavra-passe antes de desativar
      final passController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirmar Desativação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Insere a tua palavra-passe atual para desativar a proteção:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Palavra-passe'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final ok = AuthService.verifyAndUnlock(passController.text);
                Navigator.pop(c, ok);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
              child: const Text('Desativar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await AuthService.setLockEnabled(false);
        setState(() {});
      } else if (confirmed == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Palavra-passe incorreta.'), backgroundColor: AppTheme.dangerRed),
          );
        }
      }
    } else {
      await AuthService.setLockEnabled(true);
      setState(() {});
    }
  }

  void _showAuthSetupDialog() {
    final emailController = TextEditingController(text: AuthService.userEmail);
    final passController = TextEditingController();
    final confirmPassController = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.primaryElectric),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_person_rounded, color: AppTheme.primaryElectric),
              SizedBox(width: 8),
              Expanded(
                child: Text('Segurança VoltDrive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Define o teu email e palavra-passe para bloquear o acesso às métricas e faturamentos da app.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email do Motorista (para recuperação)',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryElectric),
                  filled: true,
                  fillColor: AppTheme.darkSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nova Palavra-passe',
                  prefixIcon: const Icon(Icons.key, color: AppTheme.accentGreen),
                  filled: true,
                  fillColor: AppTheme.darkSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirmar Palavra-passe',
                  prefixIcon: const Icon(Icons.check, color: AppTheme.accentGreen),
                  filled: true,
                  fillColor: AppTheme.darkSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(localError!, style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final pass = passController.text.trim();
                final confirm = confirmPassController.text.trim();

                if (email.isEmpty || !email.contains('@')) {
                  setDlgState(() => localError = 'Insere um endereço de email válido.');
                  return;
                }
                if (pass.length < 4) {
                  setDlgState(() => localError = 'A palavra-passe deve ter pelo menos 4 caracteres.');
                  return;
                }
                if (pass != confirm) {
                  setDlgState(() => localError = 'As palavras-passe não coincidem.');
                  return;
                }

                final ok = await AuthService.setupCredentials(
                  email: email,
                  password: pass,
                  enableLock: true,
                );

                if (ok) {
                  if (c.mounted) Navigator.pop(c);
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔒 Proteção por palavra-passe configurada e ativada!'),
                        backgroundColor: AppTheme.accentGreen,
                      ),
                    );
                  }
                } else {
                  setDlgState(() => localError = 'Erro ao guardar credenciais.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              child: const Text('Guardar e Ativar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
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
