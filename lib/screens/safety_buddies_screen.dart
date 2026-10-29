import 'package:flutter/material.dart';
import '../models/buddy_member.dart';
import '../models/emergency_contact.dart';
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
  bool _obscurePassword = true;

  final TextEditingController _teamCodeController = TextEditingController();
  final TextEditingController _teamPasswordController = TextEditingController();
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
    _teamPasswordController.dispose();
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
    _teamPasswordController.text = BuddySafetyService.teamPassword;
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

  Future<void> _triggerSos({bool sendToWhatsApp = true}) async {
    setState(() => _isLoadingLoc = true);
    var loc = _myLocation;
    loc ??= await AssistantService.getCurrentLocation();
    loc ??= LocationResult(latitude: 38.65, longitude: -9.15, accuracy: 50, speed: 0);
    _myLocation = loc;
    _isLoadingLoc = false;

    final url = loc.googleMapsUrl;
    final text = '🚨 ALERTA SOS TVDE: Preciso de apoio urgente no Renault Zoe!\n'
        '📍 Coordenadas: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)} (Precisão: ±${loc.accuracy.toStringAsFixed(0)}m)\n'
        '🗺️ Ver localização em direto: $url';

    // 1. Abrir WhatsApp diretamente com mensagem pré-preenchida (para Grupo TVDE ou Contacto)
    if (sendToWhatsApp) {
      await AssistantService.shareWhatsApp(phone: BuddySafetyService.emergencyPhone, message: text);
    }

    // 2. Disparar também na rede da app como contingência
    BuddySafetyService.sendSosAlert(loc, customMessage: '🚨 SOS TVDE disparado via WhatsApp');

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Alerta SOS com localização GPS aberto no WhatsApp! Seleciona o teu Grupo TVDE para enviar.'),
          backgroundColor: Color(0xFF25D366),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _shareViaWhatsAppOrSms() {
    final loc = _myLocation;
    final url = loc != null ? loc.googleMapsUrl : 'https://maps.google.com/?q=38.65,-9.15';
    final text = '🚨 ALERTA SOS TVDE: Preciso de apoio urgente no Renault Zoe!\nMinha localização em direto: $url';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final contacts = BuddySafetyService.emergencyContacts;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 24),
                          SizedBox(width: 8),
                          Text('Partilhar SOS Imediato', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Escolhe um contacto ou envia para um Grupo de WhatsApp com 1 toque:',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  // Botão Geral: Enviar para Grupo ou Escolher na Lista do WhatsApp
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      AssistantService.shareWhatsApp(phone: '', message: text);
                    },
                    icon: const Icon(Icons.groups_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      'Abrir WhatsApp (Grupo TVDE ou Escolher Contacto)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.darkBorder),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CONTACTOS RÁPIDOS:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryElectric, letterSpacing: 0.5),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddContactDialog(onAdded: () => setSheetState(() {})),
                        icon: const Icon(Icons.add, size: 16, color: AppTheme.accentGreen),
                        label: const Text('Adicionar Número', style: TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (contacts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Ainda não guardaste contactos rápidos.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showAddContactDialog(onAdded: () => setSheetState(() {})),
                            icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.black),
                            label: const Text('Adicionar Colega / Central', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryElectric),
                          ),
                        ],
                      ),
                    )
                  else
                    ...contacts.map((contact) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryElectric.withOpacity(0.2),
                            child: Text(
                              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'C',
                              style: const TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                Text(contact.phone, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          // Botão WhatsApp Rápido
                          IconButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              AssistantService.shareWhatsApp(phone: contact.phone, message: text);
                            },
                            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 22),
                            tooltip: 'Enviar WhatsApp',
                          ),
                          // Botão SMS Rápido
                          IconButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              AssistantService.sendEmergencySms(phone: contact.phone, message: text);
                            },
                            icon: const Icon(Icons.sms_outlined, color: AppTheme.primaryElectric, size: 22),
                            tooltip: 'Enviar SMS',
                          ),
                          // Apagar Contacto
                          IconButton(
                            onPressed: () async {
                              await BuddySafetyService.removeEmergencyContact(contact.id);
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 18),
                            tooltip: 'Remover',
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddContactDialog({VoidCallback? onAdded}) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: AppTheme.accentGreen, size: 22),
            SizedBox(width: 8),
            Text('Novo Contacto de SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome do Colega / Empresa',
                hintText: 'Ex: João TVDE, Central, Miguel',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número de Telemóvel',
                hintText: 'Ex: 912345678',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (phone.isNotEmpty) {
                await BuddySafetyService.addEmergencyContact(name, phone);
                if (mounted) Navigator.pop(dlgCtx);
                onAdded?.call();
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            child: const Text('Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
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
          title: const Text('Definições do Grupo & SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _teamCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome / Código do Grupo',
                    hintText: 'Ex: TVDE-LISBOA, FROTA-ZOE',
                    prefixIcon: Icon(Icons.group_outlined, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _teamPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Palavra-passe do Grupo (Proteção)',
                    hintText: 'Deixa vazio se for grupo aberto',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryElectric),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted),
                      onPressed: () => setDialogState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '🔒 Apenas quem tiver o mesmo código e palavra-passe acederá aos alertas e ao radar do grupo.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
                    labelText: 'Contacto WhatsApp Direto (Opcional)',
                    hintText: 'Deixa vazio para escolher o Grupo no WhatsApp',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryElectric),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '💡 Se deixares vazio, ao disparar o SOS abre diretamente o WhatsApp para escolheres o teu Grupo TVDE.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
                  newTeamPassword: _teamPasswordController.text,
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
            // BOTÃO PRINCIPAL: DISPARAR SOS DIRETO PARA GRUPO WHATSAPP
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _triggerSos(sendToWhatsApp: true),
                icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 24),
                label: const Text(
                  'DISPARAR SOS PARA GRUPO WHATSAPP',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // Verde oficial WhatsApp
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.dangerRed, width: 2),
                  ),
                  elevation: 6,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _triggerSos(sendToWhatsApp: false),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.dangerRed),
                    label: const Text('Alerta de Rede (App)', style: TextStyle(fontSize: 12, color: AppTheme.dangerRed, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.5)),
                      backgroundColor: AppTheme.darkSurface,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareViaWhatsAppOrSms,
                    icon: const Icon(Icons.sms_outlined, size: 18, color: AppTheme.primaryElectric),
                    label: const Text('SMS / Contactos', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.darkBorder),
                      backgroundColor: AppTheme.darkSurface,
                      padding: const EdgeInsets.symmetric(vertical: 11),
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
              InkWell(
                onTap: _openSettingsDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: BuddySafetyService.teamPassword.isNotEmpty
                          ? AppTheme.accentGreen.withOpacity(0.6)
                          : AppTheme.darkBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        BuddySafetyService.teamPassword.isNotEmpty ? Icons.lock : Icons.lock_open,
                        size: 12,
                        color: BuddySafetyService.teamPassword.isNotEmpty
                            ? AppTheme.accentGreen
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${BuddySafetyService.teamCode}${BuddySafetyService.teamPassword.isNotEmpty ? ' (Protegido)' : ''}',
                        style: TextStyle(
                          color: BuddySafetyService.teamPassword.isNotEmpty
                              ? AppTheme.accentGreen
                              : AppTheme.primaryElectric,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.people_outline, color: AppTheme.textMuted, size: 36),
                    const SizedBox(height: 8),
                    const Text('Nenhum colega ligado neste canal.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Partilha o código "${BuddySafetyService.teamCode}" com outros motoristas para se verem aqui no radar!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
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
        ],
      ),
    );
  }
}
