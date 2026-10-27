import 'package:flutter/material.dart';
import '../models/buddy_member.dart';
import '../services/assistant_service.dart';
import '../services/buddy_safety_service.dart';
import '../theme/app_theme.dart';

class SafetyBuddiesScreen extends StatefulWidget {
  const SafetyBuddiesScreen({super.key});

  @override
  State<SafetyBuddiesScreen> createState() => _SafetyBuddiesScreenState();
}

class _SafetyBuddiesScreenState extends State<SafetyBuddiesScreen> {
  LocationResult? _myLocation;
  bool _isLoadingLoc = false;

  final TextEditingController _teamCodeController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    BuddySafetyService.updatesNotifier.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    BuddySafetyService.updatesNotifier.removeListener(_onServiceUpdate);
    _teamCodeController.dispose();
    _driverNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    await BuddySafetyService.loadConfig();
    _teamCodeController.text = BuddySafetyService.teamCode;
    _driverNameController.text = BuddySafetyService.driverName;
    _emergencyPhoneController.text = BuddySafetyService.emergencyPhone;
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    setState(() => _isLoadingLoc = true);
    final loc = await AssistantService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _myLocation = loc;
        _isLoadingLoc = false;
      });
      if (loc != null && BuddySafetyService.isSharingActive) {
        BuddySafetyService.broadcastMyLocation(loc);
      }
    }
  }

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.dangerRed, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 28),
            SizedBox(width: 8),
            Text('Disparar Alerta SOS?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Isto vai enviar um alerta urgente com as tuas coordenadas GPS para todos os colegas da equipa "${BuddySafetyService.teamCode}".\n\n${BuddySafetyService.isDiscreetMode ? "🤫 Modo Discreto ativado: o teu telemóvel não fará barulho." : ""}',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('SIM, ENVIAR SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      var loc = _myLocation;
      loc ??= await AssistantService.getCurrentLocation();
      loc ??= LocationResult(latitude: 38.65, longitude: -9.15, accuracy: 50, speed: 0);

      await BuddySafetyService.sendSosAlert(loc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Alerta SOS enviado para a rede de colegas!'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  void _shareViaWhatsAppOrSms() {
    final loc = _myLocation;
    final url = loc != null ? loc.googleMapsUrl : 'https://maps.google.com/?q=38.65,-9.15';
    final text = '🚨 ALERTA SOS TVDE: Preciso de apoio urgente no Renault Zoe!\nMinha localização em direto: $url';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Partilhar Alerta SOS Rápido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                AssistantService.shareWhatsApp(phone: BuddySafetyService.emergencyPhone, message: text);
              },
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: const Text('Enviar por WhatsApp'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                AssistantService.sendEmergencySms(phone: BuddySafetyService.emergencyPhone, message: text);
              },
              icon: const Icon(Icons.sms_outlined, color: Colors.white),
              label: const Text('Enviar por SMS'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryElectric),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Definições da Equipa & SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _teamCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código da Equipa (Partilhar com Amigos)',
                    prefixIcon: Icon(Icons.group_outlined, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _driverNameController,
                  decoration: const InputDecoration(
                    labelText: 'O Teu Nome / Indicativo',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contacto de Emergência (Colega)',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modo Silencioso / Discreto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Não toca som no teu telemóvel ao disparar SOS', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: BuddySafetyService.isDiscreetMode,
                  activeColor: AppTheme.accentGreen,
                  onChanged: (val) => setDialogState(() => BuddySafetyService.isDiscreetMode = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Partilha de Localização', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Visível para os colegas da equipa', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: BuddySafetyService.isSharingActive,
                  activeColor: AppTheme.accentGreen,
                  onChanged: (val) => setDialogState(() => BuddySafetyService.isSharingActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                await BuddySafetyService.saveConfig(
                  newTeamCode: _teamCodeController.text,
                  newDriverName: _driverNameController.text,
                  newEmergencyPhone: _emergencyPhoneController.text,
                  newDiscreetMode: BuddySafetyService.isDiscreetMode,
                  newSharingActive: BuddySafetyService.isSharingActive,
                );
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              child: const Text('Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incomingSos = BuddySafetyService.activeIncomingSos;
    final isMySos = BuddySafetyService.isMySosActive;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Segurança & Colegas TVDE'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
            tooltip: 'Definições de Segurança',
            onPressed: _openSettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🚨 ALERTA SOS RECEBIDO DE UM COLEGA
            if (incomingSos != null) ...[
              _buildIncomingSosAlert(incomingSos),
              const SizedBox(height: 16),
            ],

            // BOTÃO SOS PRINCIPAL
            _buildSosActionCard(isMySos),

            const SizedBox(height: 16),

            // MINHA LOCALIZAÇÃO & STATUS
            _buildMyLocationCard(),

            const SizedBox(height: 16),

            // RADAR DE COLEGAS
            _buildBuddiesRadarCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingSosAlert(BuddyMember sos) {
    final dist = _myLocation != null
        ? '${sos.distanceToKm(_myLocation!.latitude, _myLocation!.longitude).toStringAsFixed(1)} km'
        : 'Perto de ti';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerRed, width: 2),
        boxShadow: [
          BoxShadow(color: AppTheme.dangerRed.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '🚨 ALERTA SOS DO COLEGA!',
                    style: const TextStyle(color: AppTheme.dangerRed, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                onPressed: () => setState(() => BuddySafetyService.dismissIncomingSos()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${sos.name} acionou o SOS no seu ${sos.vehicle}!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          if (sos.sosMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '"${sos.sosMessage}"',
                style: const TextStyle(color: AppTheme.warningAmber, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.near_me, color: AppTheme.primaryElectric, size: 14),
                    const SizedBox(width: 4),
                    Text('Distância: $dist', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.battery_charging_full, color: AppTheme.accentGreen, size: 14),
                    const SizedBox(width: 4),
                    Text('Zoe: ${sos.batteryPercent}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => AssistantService.openUrl(sos.googleMapsUrl),
              icon: const Icon(Icons.navigation_rounded, color: Colors.white),
              label: const Text('Navegar até ao Colega (Google Maps / Waze)', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosActionCard(bool isMySos) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isMySos ? AppTheme.dangerRed.withOpacity(0.15) : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMySos ? AppTheme.dangerRed : AppTheme.darkBorder, width: 1.5),
      ),
      child: Column(
        children: [
          if (isMySos) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, color: AppTheme.dangerRed, size: 24),
                SizedBox(width: 8),
                Text(
                  'O TEU ALERTA SOS ESTÁ ATIVO!',
                  style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'A tua localização está a ser transmitida para a rede de colegas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await BuddySafetyService.cancelMySos();
                  setState(() {});
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.black),
                label: const Text('ESTOU EM SEGURANÇA (Cancelar SOS)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield, color: AppTheme.dangerRed, size: 24),
                    const SizedBox(width: 8),
                    const Text('Botão de Pânico / SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryElectric.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    BuddySafetyService.isDiscreetMode ? '🤫 DISCRETO' : '📢 AUDÍVEL',
                    style: const TextStyle(color: AppTheme.primaryElectric, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Em caso de perigo ou agressão, envia instantaneamente a tua localização GPS para os teus colegas TVDE.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _triggerSos,
                icon: const Icon(Icons.emergency_share, color: Colors.white, size: 24),
                label: const Text(
                  'DISPARAR ALERTA SOS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareViaWhatsAppOrSms,
                    icon: const Icon(Icons.share, size: 16, color: AppTheme.primaryElectric),
                    label: const Text('Partilhar por SMS / WhatsApp', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.darkBorder),
                      backgroundColor: AppTheme.darkSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyLocationCard() {
    final loc = _myLocation;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.my_location, color: AppTheme.primaryElectric, size: 18),
                  SizedBox(width: 8),
                  Text('Minha Posição GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              IconButton(
                icon: _isLoadingLoc
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryElectric))
                    : const Icon(Icons.refresh, size: 18, color: AppTheme.primaryElectric),
                onPressed: _refreshLocation,
                tooltip: 'Atualizar Coordenadas',
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (loc != null) ...[
            Text(
              'Lat: ${loc.latitude.toStringAsFixed(5)}, Lng: ${loc.longitude.toStringAsFixed(5)} (Precisão: ±${loc.accuracy.toStringAsFixed(0)}m)',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => AssistantService.openUrl(loc.googleMapsUrl),
                  icon: const Icon(Icons.open_in_new, size: 14, color: AppTheme.primaryElectric),
                  label: const Text('Abrir no Google Maps', style: TextStyle(fontSize: 12, color: AppTheme.primaryElectric)),
                ),
              ],
            ),
          ] else
            const Text('A obter sinal GPS...', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBuddiesRadarCard() {
    final list = BuddySafetyService.colleagues;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar, color: AppTheme.accentGreen, size: 20),
                  const SizedBox(width: 8),
                  const Text('Radar de Colegas Ativos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Text(
                  'Canal: ${BuddySafetyService.teamCode}',
                  style: const TextStyle(color: AppTheme.primaryElectric, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Nenhum colega ativo no canal agora.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(color: AppTheme.darkBorder, height: 16),
              itemBuilder: (ctx, i) {
                final c = list[i];
                final dist = _myLocation != null
                    ? '${c.distanceToKm(_myLocation!.latitude, _myLocation!.longitude).toStringAsFixed(1)} km'
                    : '--';

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: c.isSosActive
                          ? AppTheme.dangerRed.withOpacity(0.2)
                          : AppTheme.primaryElectric.withOpacity(0.15),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0] : 'C',
                        style: TextStyle(
                          color: c.isSosActive ? AppTheme.dangerRed : AppTheme.primaryElectric,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 6),
                              if (c.isSosActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.dangerRed, borderRadius: BorderRadius.circular(6)),
                                  child: const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.vehicle} • $dist de ti • Bateria: ${c.batteryPercent}%',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigation_outlined, color: AppTheme.primaryElectric, size: 20),
                      tooltip: 'Rota para o Colega',
                      onPressed: () => AssistantService.openUrl(c.googleMapsUrl),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 12),
          // Botão de Teste para o condutor simular
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                BuddySafetyService.simulateIncomingSosFromColleague();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚡ A simular receção de SOS de um colega da equipa!'),
                    backgroundColor: AppTheme.warningAmber,
                  ),
                );
              },
              icon: const Icon(Icons.bug_report_outlined, size: 16, color: AppTheme.warningAmber),
              label: const Text('Testar Receção de SOS de Colega', style: TextStyle(fontSize: 12, color: AppTheme.warningAmber)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.darkBorder)),
            ),
          ),
        ],
      ),
    );
  }
}
