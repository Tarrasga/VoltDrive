import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/driving_session.dart';
import '../services/assistant_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class DrivingHoursScreen extends StatefulWidget {
  const DrivingHoursScreen({super.key});

  @override
  State<DrivingHoursScreen> createState() => _DrivingHoursScreenState();
}

class _DrivingHoursScreenState extends State<DrivingHoursScreen> {
  DrivingShiftSession _session = DrivingShiftSession(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    date: DateTime.now(),
  );

  List<DrivingShiftSession> _history = [];
  int _selectedTab = 0; // 0 = Turno em Curso, 1 = Dias Anteriores

  Timer? _ticker;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final loaded = await StorageService.loadCurrentDrivingSession();
    final history = await StorageService.loadDrivingHistory();
    setState(() {
      _session = loaded;
      _history = history;
      _isLoading = false;
    });

    if (_session.currentState != DrivingState.parado) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_session.currentState == DrivingState.conduzindo) {
          _session.totalDrivingSeconds++;
          _session.currentContinuousDrivingSeconds++;
        } else if (_session.currentState == DrivingState.emPausa) {
          _session.totalBreakSeconds++;
        }
      });
      // Salva a cada 30 segundos
      if (_session.totalDrivingSeconds % 30 == 0) {
        StorageService.saveCurrentDrivingSession(_session);
      }
    });
  }

  Future<void> _startDriving() async {
    final kmController = TextEditingController(text: _session.startKm != null ? _session.startKm!.toStringAsFixed(0) : '');
    final inputKm = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Iniciar Turno TVDE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registo obrigatório: Introduz o odómetro do carro no início do turno (Km Inicial):', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            TextField(
              controller: kmController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Km Inicial (Odómetro)',
                prefixIcon: Icon(Icons.pin_drop_outlined, color: AppTheme.primaryElectric),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Mais Tarde', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(kmController.text.replaceAll(',', '.'));
              Navigator.pop(ctx, val);
            },
            child: const Text('Confirmar & Iniciar'),
          ),
        ],
      ),
    );

    final now = DateTime.now();
    setState(() {
      _session.shiftStartTime ??= now;
      if (inputKm != null && inputKm > 0) {
        _session.startKm = inputKm;
      }
      _session.currentState = DrivingState.conduzindo;
      _session.logs.insert(
        0,
        DrivingSessionLog(
          timestamp: now,
          description: _session.startKm != null ? 'Início de Condução (Km: ${_session.startKm!.toStringAsFixed(0)})' : 'Início de Condução',
          state: DrivingState.conduzindo,
        ),
      );
    });
    _startTicker();
    StorageService.saveCurrentDrivingSession(_session);
  }

  void _takeBreak() {
    final now = DateTime.now();
    setState(() {
      _session.currentState = DrivingState.emPausa;
      _session.logs.insert(
        0,
        DrivingSessionLog(
          timestamp: now,
          description: 'Início de Pausa / Descanso',
          state: DrivingState.emPausa,
        ),
      );
    });
    StorageService.saveCurrentDrivingSession(_session);
  }

  void _resumeDrivingAfterBreak() {
    final now = DateTime.now();
    setState(() {
      // Se a pausa foi de pelo menos 45 minutos (ou 15 min parciais), reinicia o contador contínuo
      if (_session.totalBreakSeconds >= 45 * 60) {
        _session.currentContinuousDrivingSeconds = 0;
      }
      _session.currentState = DrivingState.conduzindo;
      _session.logs.insert(
        0,
        DrivingSessionLog(
          timestamp: now,
          description: 'Retoma de Condução',
          state: DrivingState.conduzindo,
        ),
      );
    });
    StorageService.saveCurrentDrivingSession(_session);
  }

  void _resetContinuousTimerManual() {
    setState(() {
      _session.currentContinuousDrivingSeconds = 0;
      _session.logs.insert(
        0,
        DrivingSessionLog(
          timestamp: DateTime.now(),
          description: 'Pausa de 45m validada manualmente',
          state: DrivingState.emPausa,
        ),
      );
    });
    StorageService.saveCurrentDrivingSession(_session);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contador de 4h reiniciado (Pausa de 45 min validada).'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  Future<void> _endShift() async {
    final endKmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Encerrar Turno de Condução?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total conduzido hoje: ${_session.formatHoursAndMins(_session.totalDrivingSeconds)}.\nDescanso obrigatório de 11h começará agora.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: endKmController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Km Final do Odómetro',
                prefixIcon: Icon(Icons.flag_outlined, color: AppTheme.accentGreen),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Sim, Encerrar Turno'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _ticker?.cancel();
      final now = DateTime.now();
      final endKm = double.tryParse(endKmController.text.replaceAll(',', '.'));
      setState(() {
        _session.shiftEndTime = now;
        if (endKm != null && endKm > 0) {
          _session.endKm = endKm;
        }
        _session.currentState = DrivingState.parado;
        
        final kmDrivenStr = _session.totalKmDriven > 0 ? ' (Km Feitos: ${_session.totalKmDriven.toStringAsFixed(1)} km)' : '';
        _session.logs.insert(
          0,
          DrivingSessionLog(
            timestamp: now,
            description: 'Turno Encerrado$kmDrivenStr',
            state: DrivingState.parado,
          ),
        );
      });
      await StorageService.archiveDrivingSession(_session);
      await StorageService.saveCurrentDrivingSession(_session);
      final history = await StorageService.loadDrivingHistory();
      if (!mounted) return;

      setState(() {
        _history = history;
      });

      final kmMsg = _session.totalKmDriven > 0 ? ' | Km: ${_session.totalKmDriven.toStringAsFixed(1)} km' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Turno arquivado com sucesso!$kmMsg'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _openAddManualSessionDialog({DrivingShiftSession? existing}) async {
    DateTime selectedDate = existing?.date ?? DateTime.now().subtract(const Duration(days: 1));
    final hoursCtrl = TextEditingController(text: existing != null ? (existing.totalDrivingSeconds / 3600.0).toStringAsFixed(1) : '8.0');
    final breaksCtrl = TextEditingController(text: existing != null ? (existing.totalBreakSeconds / 60).toStringAsFixed(0) : '45');
    final startKmCtrl = TextEditingController(text: existing?.startKm != null && existing!.startKm! > 0 ? existing.startKm!.toStringAsFixed(0) : '');
    final endKmCtrl = TextEditingController(text: existing?.endKm != null && existing!.endKm! > 0 ? existing.endKm!.toStringAsFixed(0) : '');
    final manualKmCtrl = TextEditingController(text: existing?.totalKmDriven != null && existing!.totalKmDriven > 0 ? existing.totalKmDriven.toStringAsFixed(1) : '');

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.history_toggle_off, color: AppTheme.primaryElectric, size: 22),
              const SizedBox(width: 8),
              Text(
                existing != null ? 'Editar Registo de Horas' : 'Registar Horas de Dia Anterior',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Registo para fiscalização TVDE e sincronização automática de lucros:',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),

                // Seletor de Data
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primaryElectric,
                            surface: AppTheme.darkCard,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDlgState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryElectric),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                          ],
                        ),
                        const Text('Alterar Data', style: TextStyle(color: AppTheme.primaryElectric, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Horas de Condução e Pausas
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Horas Condução',
                          hintText: '8.5',
                          suffixText: 'h',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: breaksCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Pausas (min)',
                          hintText: '45',
                          suffixText: 'min',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Odómetro / Km
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startKmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Km Inicial',
                          hintText: 'Ex: 124500',
                        ),
                        onChanged: (_) {
                          final s = double.tryParse(startKmCtrl.text.replaceAll(',', '.')) ?? 0;
                          final e = double.tryParse(endKmCtrl.text.replaceAll(',', '.')) ?? 0;
                          if (e > s && s > 0) {
                            manualKmCtrl.text = (e - s).toStringAsFixed(1);
                            setDlgState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: endKmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Km Final',
                          hintText: 'Ex: 124785',
                        ),
                        onChanged: (_) {
                          final s = double.tryParse(startKmCtrl.text.replaceAll(',', '.')) ?? 0;
                          final e = double.tryParse(endKmCtrl.text.replaceAll(',', '.')) ?? 0;
                          if (e > s && s > 0) {
                            manualKmCtrl.text = (e - s).toStringAsFixed(1);
                            setDlgState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: manualKmCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total Km Conduzidos',
                    hintText: 'Ex: 285.0',
                    suffixText: 'km',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final hours = double.tryParse(hoursCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final breakMins = int.tryParse(breaksCtrl.text) ?? 45;
                final startKm = double.tryParse(startKmCtrl.text.replaceAll(',', '.'));
                final endKm = double.tryParse(endKmCtrl.text.replaceAll(',', '.'));
                final manualKm = double.tryParse(manualKmCtrl.text.replaceAll(',', '.'));

                final totalSecs = (hours * 3600).round();
                final breakSecs = breakMins * 60;

                final startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8, 0);
                final endTime = startTime.add(Duration(seconds: totalSecs + breakSecs));

                final session = DrivingShiftSession(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  date: selectedDate,
                  shiftStartTime: startTime,
                  shiftEndTime: endTime,
                  startKm: startKm,
                  endKm: endKm,
                  manualKm: manualKm,
                  totalDrivingSeconds: totalSecs,
                  totalBreakSeconds: breakSecs,
                  currentContinuousDrivingSeconds: 0,
                  currentState: DrivingState.parado,
                  logs: [
                    DrivingSessionLog(
                      timestamp: startTime,
                      description: startKm != null ? 'Início de Condução (Km: ${startKm.toStringAsFixed(0)})' : 'Início de Condução',
                      state: DrivingState.conduzindo,
                    ),
                    DrivingSessionLog(
                      timestamp: startTime.add(const Duration(hours: 4)),
                      description: 'Pausa de ${breakMins}m',
                      state: DrivingState.emPausa,
                    ),
                    DrivingSessionLog(
                      timestamp: endTime,
                      description: endKm != null ? 'Turno Encerrado (Km: ${endKm.toStringAsFixed(0)})' : 'Turno Encerrado',
                      state: DrivingState.parado,
                    ),
                  ],
                );

                await StorageService.archiveDrivingSession(session);
                final history = await StorageService.loadDrivingHistory();
                if (mounted) {
                  setState(() {
                    _history = history;
                  });
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Registo de horas guardado com sucesso!'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              child: const Text('Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _shareSessionRecord(DrivingShiftSession s) {
    final dateStr = DateFormat('dd/MM/yyyy').format(s.date);
    final totalHoursStr = s.formatHoursAndMins(s.totalDrivingSeconds);
    final totalBreaksStr = s.formatHoursAndMins(s.totalBreakSeconds);
    final kmStr = s.totalKmDriven > 0 ? '${s.totalKmDriven.toStringAsFixed(1)} km' : 'N/D';
    final startKmStr = s.startKm != null ? '${s.startKm!.toStringAsFixed(0)} km' : 'N/D';
    final endKmStr = s.endKm != null ? '${s.endKm!.toStringAsFixed(0)} km' : 'N/D';
    final startTimeStr = s.shiftStartTime != null ? DateFormat('HH:mm').format(s.shiftStartTime!) : 'N/D';
    final endTimeStr = s.shiftEndTime != null ? DateFormat('HH:mm').format(s.shiftEndTime!) : 'N/D';

    final sb = StringBuffer();
    sb.writeln('📋 VOLTDRIVE • REGISTO DE HORAS TVDE (LEI N.º 45/2018)');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('Data do Turno: $dateStr');
    sb.writeln('Horário: $startTimeStr ➔ $endTimeStr');
    sb.writeln('Tempo de Condução Total: $totalHoursStr (Máx. legal: 10h)');
    sb.writeln('Pausas e Descanso: $totalBreaksStr (Mín. legal: 45 min)');
    sb.writeln('Odómetro: $startKmStr ➔ $endKmStr ($kmStr)');
    sb.writeln('Conformidade Legal: ${s.totalDrivingSeconds <= 10 * 3600 ? "CONFORME (Art.º 15.º Lei TVDE)" : "EXCEDIDO (+${s.formatHoursAndMins(s.totalDrivingSeconds - 10 * 3600)})"}');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('HISTÓRICO DE AUDITORIA / EVENTOS:');
    for (final l in s.logs) {
      sb.writeln('• ${DateFormat("HH:mm:ss").format(l.timestamp)} - ${l.description}');
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('Gerado pelo assistente VoltDrive (Renault Zoe Edition)');

    AssistantService.shareFile(
      fileName: 'VoltDrive_Horas_TVDE_${dateStr.replaceAll("/", "_")}.txt',
      content: sb.toString(),
      mimeType: 'text/plain',
      title: 'Registo TVDE - $dateStr',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryElectric)),
      );
    }

    final dailyRatio = _session.dailyUsageRatio;
    final continuousRatio = _session.continuousUsageRatio;
    final isLimitReached = _session.isDailyLimitReached;
    final isBreakMandatory = _session.isBreakMandatory;

    // Cores dinâmicas para o estado diário
    Color dailyColor = AppTheme.primaryElectric;
    if (dailyRatio >= 0.90) {
      dailyColor = AppTheme.dangerRed;
    } else if (dailyRatio >= 0.75) {
      dailyColor = AppTheme.warningAmber;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Horas TVDE (Tacógrafo)'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _selectedTab == 0 ? Icons.history_rounded : Icons.timer_outlined,
              color: AppTheme.primaryElectric,
            ),
            tooltip: _selectedTab == 0 ? 'Ver Dias Anteriores' : 'Ver Turno em Curso',
            onPressed: () {
              setState(() {
                _selectedTab = _selectedTab == 0 ? 1 : 0;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // SELETOR DE ABAS: [ ⏱️ Turno em Curso ] | [ 📜 Dias Anteriores (X) ]
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppTheme.primaryElectric : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 15,
                            color: _selectedTab == 0 ? Colors.black : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Turno em Curso',
                            style: TextStyle(
                              color: _selectedTab == 0 ? Colors.black : AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppTheme.accentGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 16,
                            color: _selectedTab == 1 ? Colors.black : AppTheme.accentGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Dias Anteriores (${_history.length})',
                            style: TextStyle(
                              color: _selectedTab == 1 ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? _buildActiveShiftTab(dailyColor, dailyRatio, continuousRatio, isLimitReached, isBreakMandatory)
                : _buildHistoryTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveShiftTab(Color dailyColor, double dailyRatio, double continuousRatio, bool isLimitReached, bool isBreakMandatory) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CARTÃO PRINCIPAL: CRONÓMETRO DAS 10 HORAS LEGAIS
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: dailyColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: dailyColor.withOpacity(0.18),
                  blurRadius: 18,
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
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _session.currentState == DrivingState.conduzindo
                                ? AppTheme.accentGreen
                                : (_session.currentState == DrivingState.emPausa
                                    ? AppTheme.warningAmber
                                    : AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _session.currentState == DrivingState.conduzindo
                              ? 'A CONDUZIR'
                              : (_session.currentState == DrivingState.emPausa
                                  ? 'EM PAUSA / DESCANSO'
                                  : 'TURNO PARADO'),
                          style: TextStyle(
                            color: _session.currentState == DrivingState.conduzindo
                                ? AppTheme.accentGreen
                                : (_session.currentState == DrivingState.emPausa
                                    ? AppTheme.warningAmber
                                    : AppTheme.textMuted),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: dailyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Máx: 10h (Lei TVDE)',
                        style: TextStyle(
                          color: dailyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // CRONÓMETRO GIGANTE
                Text(
                  _session.formatSeconds(_session.totalDrivingSeconds),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isLimitReached ? AppTheme.dangerRed : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Restam ${_session.formatHoursAndMins(_session.remainingDailyDrivingSeconds)} de condução hoje',
                  style: TextStyle(
                    fontSize: 13,
                    color: isLimitReached ? AppTheme.dangerRed : AppTheme.textMuted,
                    fontWeight: isLimitReached ? FontWeight.bold : FontWeight.normal,
                  ),
                ),

                const SizedBox(height: 14),

                // BARRA DE PROGRESSO DAS 10 HORAS
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: dailyRatio,
                    backgroundColor: AppTheme.darkBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(dailyColor),
                    minHeight: 10,
                  ),
                ),
                if (_session.startKm != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Odómetro Inicial: ${_session.startKm!.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      if (_session.endKm != null)
                        Text('Final: ${_session.endKm!.toStringAsFixed(0)} km (+${_session.totalKmDriven.toStringAsFixed(1)} km)', style: const TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // CARTÃO DE BLOCO CONTÍNUO (4 HORAS MÁXIMAS ANTES DE PAUSA)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isBreakMandatory ? AppTheme.dangerRed : AppTheme.darkBorder,
                width: isBreakMandatory ? 2 : 1,
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
                          isBreakMandatory ? Icons.warning_amber_rounded : Icons.coffee_outlined,
                          color: isBreakMandatory ? AppTheme.dangerRed : AppTheme.warningAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Condução Contínua (Máx. 4h)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      _session.formatHoursAndMins(_session.currentContinuousDrivingSeconds),
                      style: TextStyle(
                        color: isBreakMandatory ? AppTheme.dangerRed : AppTheme.warningAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: continuousRatio,
                    backgroundColor: AppTheme.darkBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isBreakMandatory ? AppTheme.dangerRed : AppTheme.warningAmber,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isBreakMandatory
                          ? '⚠️ OBRIGATÓRIO: Paragem de 45 min agora!'
                          : 'Próxima pausa obrigatória em: ${_session.formatHoursAndMins(_session.remainingContinuousDrivingSeconds)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isBreakMandatory ? AppTheme.dangerRed : AppTheme.textMuted,
                        fontWeight: isBreakMandatory ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    TextButton(
                      onPressed: _resetContinuousTimerManual,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                      child: const Text('Já fiz pausa', style: TextStyle(fontSize: 11, color: AppTheme.primaryElectric)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // BOTÕES DE CONTROLO DE AÇÃO (Grandes para o suporte do carro)
          if (_session.currentState == DrivingState.parado)
            ElevatedButton.icon(
              onPressed: isLimitReached ? null : _startDriving,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('INICIAR TURNO / CONDUZIR', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            )
          else if (_session.currentState == DrivingState.conduzindo)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _takeBreak,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.coffee_rounded, size: 24),
                    label: const Text('FAZER PAUSA (45m)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _endShift,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: AppTheme.dangerRed),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 22),
                    label: const Text('ENCERRAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          else if (_session.currentState == DrivingState.emPausa)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _resumeDrivingAfterBreak,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text('RETOMAR CONDUÇÃO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _endShift,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: AppTheme.dangerRed),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 22),
                    label: const Text('ENCERRAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // HISTÓRICO DE EVENTOS DO TURNO (AUDIT TRAIL / FISCALIZAÇÃO)
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
                          Icon(Icons.receipt_long, color: AppTheme.primaryElectric, size: 20),
                          SizedBox(width: 8),
                          Text('Registo do Dia (Fiscalização TVDE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Text(
                        'Pausas: ${_session.formatHoursAndMins(_session.totalBreakSeconds)}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.darkBorder, height: 20),
                  if (_session.logs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Nenhum evento registado hoje.\nClica em "Iniciar Turno" para começar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _session.logs.length.clamp(0, 8),
                      separatorBuilder: (_, __) => const Divider(color: AppTheme.darkBorder, height: 12),
                      itemBuilder: (context, index) {
                        final log = _session.logs[index];
                        final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
                        Color iconColor = AppTheme.primaryElectric;
                        if (log.state == DrivingState.conduzindo) iconColor = AppTheme.accentGreen;
                        if (log.state == DrivingState.emPausa) iconColor = AppTheme.warningAmber;
                        if (log.state == DrivingState.parado) iconColor = AppTheme.dangerRed;

                        return Row(
                          children: [
                            Text(timeStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Icon(Icons.circle, color: iconColor, size: 8),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(log.description, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // LEMBRETE DA LEI TVDE PORTUGAL
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel, color: AppTheme.primaryElectric, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lei TVDE Portugal (Lei n.º 45/2018): Máx. 10 horas de condução em 24h. Pausa mínima de 45 min a cada 4 horas de condução contínua. Descanso diário obrigatório de 11h.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_toggle_off_rounded, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Sem Turnos Anteriores Arquivados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Os teus turnos encerrados em dias anteriores aparecem aqui para consulta e fiscalização TVDE (Lei n.º 45/2018).\nTambém podes registar dias anteriores manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openAddManualSessionDialog(),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Adicionar Horas de Dia Anterior', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryElectric),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_history.length} Turnos Arquivados',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddManualSessionDialog(),
                icon: const Icon(Icons.add, size: 16, color: Colors.black),
                label: const Text('Adicionar Dia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryElectric,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final session = _history[index];
              final dateStr = DateFormat('EEEE, d \'de\' MMMM yyyy', 'pt_PT').format(session.date);
              final isCompliant = session.totalDrivingSeconds <= DrivingShiftSession.maxDailyDrivingSeconds;
              final drivingRatio = (session.totalDrivingSeconds / DrivingShiftSession.maxDailyDrivingSeconds).clamp(0.0, 1.0);

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCompliant ? AppTheme.darkBorder : AppTheme.dangerRed.withOpacity(0.6),
                    width: isCompliant ? 1 : 1.5,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCompliant ? AppTheme.accentGreen.withOpacity(0.15) : AppTheme.dangerRed.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCompliant ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      color: isCompliant ? AppTheme.accentGreen : AppTheme.dangerRed,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    dateStr[0].toUpperCase() + dateStr.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          'Condução: ${session.formatHoursAndMins(session.totalDrivingSeconds)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isCompliant ? AppTheme.primaryElectric : AppTheme.dangerRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  ${session.totalKmDriven.toStringAsFixed(1)} km',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(color: AppTheme.darkBorder, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildHistoryStat('Horas TVDE', session.formatHoursAndMins(session.totalDrivingSeconds), color: AppTheme.primaryElectric),
                              _buildHistoryStat('Pausas', session.formatHoursAndMins(session.totalBreakSeconds), color: AppTheme.warningAmber),
                              _buildHistoryStat('Km Rodados', '${session.totalKmDriven.toStringAsFixed(1)} km', color: AppTheme.accentGreen),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: drivingRatio,
                              backgroundColor: AppTheme.darkSurface,
                              valueColor: AlwaysStoppedAnimation<Color>(isCompliant ? AppTheme.primaryElectric : AppTheme.dangerRed),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (session.startKm != null && session.endKm != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.darkSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Odómetro Inicial: ${session.startKm!.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  Text('Final: ${session.endKm!.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                          if (session.logs.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text('Auditoria do Turno (Eventos):', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            ...session.logs.take(6).map((log) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('HH:mm').format(log.timestamp),
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('•', style: TextStyle(color: log.state == DrivingState.conduzindo ? AppTheme.accentGreen : AppTheme.warningAmber, fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      log.description,
                                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _shareSessionRecord(session),
                                  icon: const Icon(Icons.share, size: 14, color: AppTheme.primaryElectric),
                                  label: const Text('Exportar Registo', style: TextStyle(fontSize: 11, color: AppTheme.primaryElectric)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primaryElectric),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openAddManualSessionDialog(existing: session),
                                  icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                                  label: const Text('Editar', style: TextStyle(fontSize: 11, color: Colors.white)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.darkBorder),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerRed),
                                tooltip: 'Eliminar Registo',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: AppTheme.darkSurface,
                                      title: const Text('Eliminar este registo?'),
                                      content: Text('Tens a certeza que queres eliminar o registo de ${DateFormat("dd/MM/yyyy").format(session.date)}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(c, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                                          child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await StorageService.deleteDrivingSession(session.id);
                                    final history = await StorageService.loadDrivingHistory();
                                    setState(() {
                                      _history = history;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }
}
