import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/driving_session.dart';
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
    setState(() {
      _session = loaded;
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
      if (!mounted) return;

      final kmMsg = _session.totalKmDriven > 0 ? ' | Km: ${_session.totalKmDriven.toStringAsFixed(1)} km' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Turno arquivado com sucesso!$kmMsg'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
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
            Text('Horas TVDE (Tacógrafo Digital)'),
          ],
        ),
      ),
      body: SingleChildScrollView(
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
          ],
        ),
      ),
    );
  }
}
