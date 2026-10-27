import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_shift.dart';
import '../models/financial_goals.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class FinancialGoalsScreen extends StatefulWidget {
  final List<DailyShift>? preloadedShifts;

  const FinancialGoalsScreen({super.key, this.preloadedShifts});

  static Future<void> showAsModal(BuildContext context, {List<DailyShift>? shifts, VoidCallback? onSaved}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => SizedBox(
        height: MediaQuery.of(modalContext).size.height * 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: FinancialGoalsScreen(preloadedShifts: shifts),
        ),
      ),
    );
    onSaved?.call();
  }

  @override
  State<FinancialGoalsScreen> createState() => _FinancialGoalsScreenState();
}

class _FinancialGoalsScreenState extends State<FinancialGoalsScreen> {
  late TextEditingController _monthlyController;
  late TextEditingController _weeklyController;
  String _targetType = 'profit'; // 'profit' ou 'revenue'
  int _workDaysPerWeek = 6; // 5, 6 ou 7

  List<DailyShift> _shifts = [];
  FinancialGoals _goals = FinancialGoals();
  bool _isLoading = true;
  bool _isSaving = false;

  final currencyFormat = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2);

  String _formatCurrency(double value) {
    try {
      return currencyFormat.format(value);
    } catch (_) {
      return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
    }
  }

  @override
  void initState() {
    super.initState();
    _monthlyController = TextEditingController();
    _weeklyController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    _weeklyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final loadedGoals = await StorageService.loadFinancialGoals();
      final loadedShifts = widget.preloadedShifts ?? await StorageService.loadShifts();

      if (mounted) {
        setState(() {
          _goals = loadedGoals;
          _shifts = loadedShifts;
          _monthlyController.text = loadedGoals.monthlyTarget.toStringAsFixed(0);
          _weeklyController.text = loadedGoals.weeklyTarget.toStringAsFixed(0);
          _targetType = loadedGoals.targetType;
          _workDaysPerWeek = loadedGoals.workDaysPerWeek;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados de metas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);

    final mTarget = double.tryParse(_monthlyController.text.replaceAll(',', '.')) ?? _goals.monthlyTarget;
    final wTarget = double.tryParse(_weeklyController.text.replaceAll(',', '.')) ?? _goals.weeklyTarget;

    final updated = _goals.copyWith(
      monthlyTarget: mTarget,
      weeklyTarget: wTarget,
      targetType: _targetType,
      workDaysPerWeek: _workDaysPerWeek,
    );

    await StorageService.saveFinancialGoals(updated);

    if (mounted) {
      setState(() {
        _goals = updated;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎯 Metas e ritmo diário atualizados com sucesso!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryElectric)),
      );
    }

    final currentMonthlyTarget = double.tryParse(_monthlyController.text.replaceAll(',', '.')) ?? _goals.monthlyTarget;
    final currentWeeklyTarget = double.tryParse(_weeklyController.text.replaceAll(',', '.')) ?? _goals.weeklyTarget;

    final tempGoals = FinancialGoals(
      monthlyTarget: currentMonthlyTarget,
      weeklyTarget: currentWeeklyTarget,
      targetType: _targetType,
      workDaysPerWeek: _workDaysPerWeek,
    );

    final monthPace = tempGoals.calculateMonthlyPace(_shifts);
    final weekPace = tempGoals.calculateWeeklyPace(_shifts);

    final now = DateTime.now();
    const ptMonths = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final capitalizedMonth = ptMonths[(now.month - 1).clamp(0, 11)];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.track_changes_rounded, color: AppTheme.accentGreen),
            SizedBox(width: 8),
            Text('Metas & Ritmo Diário'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // DESTAQUE: RITMO DIÁRIO PARA FECHAR O MÊS
            // ==========================================
            _buildMonthPaceHeroCard(capitalizedMonth, monthPace),

            const SizedBox(height: 16),

            // ==========================================
            // DESTAQUE: RITMO DIÁRIO PARA ESTA SEMANA
            // ==========================================
            _buildWeekPaceHeroCard(weekPace),

            const SizedBox(height: 20),

            // ==========================================
            // DEFINIÇÃO DAS METAS (FORMULÁRIO)
            // ==========================================
            _buildGoalSettingsForm(),

            const SizedBox(height: 24),

            // BOTÃO GUARDAR
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveGoals,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, color: Colors.black),
                label: Text(
                  _isSaving ? 'A guardar...' : 'Guardar Metas & Atualizar Ritmo',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CARD DE DESTAQUE: META MENSAL
  // ==========================================
  Widget _buildMonthPaceHeroCard(String monthName, FinancialPaceCalculation p) {
    final bool reached = p.isTargetReached;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: reached ? AppTheme.accentGreen : AppTheme.primaryElectric.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (reached ? AppTheme.accentGreen : AppTheme.primaryElectric).withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryElectric.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryElectric, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta do Mês ($monthName)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      _targetType == 'profit' ? 'Baseado no Lucro Líquido no Bolso' : 'Baseado na Faturação Bruta',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: reached ? AppTheme.accentGreen.withOpacity(0.2) : AppTheme.primaryElectric.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${p.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: reached ? AppTheme.accentGreen : AppTheme.primaryElectric,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // BARRA DE PROGRESSO
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (p.percentage / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppTheme.darkSurface,
              color: reached ? AppTheme.accentGreen : AppTheme.primaryElectric,
            ),
          ),

          const SizedBox(height: 12),

          // VALORES ALCANÇADO VS META
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alcançado até hoje', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  Text(
                    _formatCurrency(p.achieved),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Meta Definida', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  Text(
                    _formatCurrency(p.target),
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 24, color: AppTheme.darkBorder),

          // DIVISÃO PRINCIPAL PELO NÚMERO DE DIAS RESTANTES NO MÊS
          if (!reached) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131D31),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timelapse_rounded, color: AppTheme.primaryElectric, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Faltam fechar: ${_formatCurrency(p.remaining)} em ${p.daysLeft} dias',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meta Diária Necessária:',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      Text(
                        '${_formatCurrency(p.requiredDailyPaceCalendar)} / dia',
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  if (_workDaysPerWeek < 7) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Considerando folgas (${p.workingDaysLeft} dias trabalho):',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                        Text(
                          '${_formatCurrency(p.requiredDailyPaceWorking)} / dia de condução',
                          style: const TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: AppTheme.accentGreen, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🏆 META DO MÊS ATINGIDA!',
                          style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Ultrapassada em +${_formatCurrency(-p.remaining)} de lucro extra!',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // CARD DE DESTAQUE: META SEMANAL
  // ==========================================
  Widget _buildWeekPaceHeroCard(FinancialPaceCalculation p) {
    final bool reached = p.isTargetReached;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: reached ? AppTheme.accentGreen : AppTheme.darkBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.view_week_rounded, color: AppTheme.accentGreen, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Meta Desta Semana',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: reached ? AppTheme.accentGreen.withOpacity(0.2) : AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${p.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: reached ? AppTheme.accentGreen : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (p.percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.darkSurface,
              color: reached ? AppTheme.accentGreen : const Color(0xFF10B981),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alcançado: ${_formatCurrency(p.achieved)}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              Text(
                'Meta: ${_formatCurrency(p.target)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (!reached) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Faltam ${p.daysLeft} dias na semana:',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  Text(
                    '${_formatCurrency(p.requiredDailyPaceCalendar)} / dia',
                    style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              '🎉 Parabéns! Meta semanal concluída com sucesso.',
              style: TextStyle(color: AppTheme.accentGreen.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // FORMULÁRIO DE AJUSTE DE METAS
  // ==========================================
  Widget _buildGoalSettingsForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppTheme.primaryElectric, size: 20),
              SizedBox(width: 8),
              Text(
                'Configurar Valores das Metas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // TIPO DE CÁLCULO (LUCRO VS FATURAÇÃO)
          const Text('Basear os cálculos em:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: 'Lucro Líquido Real',
                  subtitle: 'Livre de taxas e despesas',
                  selected: _targetType == 'profit',
                  onTap: () => setState(() => _targetType = 'profit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceChip(
                  label: 'Faturação Bruta',
                  subtitle: 'Total faturado Uber+Bolt',
                  selected: _targetType == 'revenue',
                  onTap: () => setState(() => _targetType = 'revenue'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // META MENSAL
          const Text('Meta Mensal (€):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _monthlyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixText: '€ / mês',
              suffixStyle: const TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.bold),
              prefixIcon: const Icon(Icons.euro, color: AppTheme.primaryElectric),
              filled: true,
              fillColor: AppTheme.darkSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          // CHIPS RÁPIDOS MÊS
          Wrap(
            spacing: 8,
            children: [1500, 2000, 2500, 3000].map((val) {
              return ActionChip(
                label: Text('$val €'),
                labelStyle: TextStyle(
                  color: _monthlyController.text == val.toString() ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                backgroundColor: _monthlyController.text == val.toString() ? AppTheme.primaryElectric : AppTheme.darkSurface,
                onPressed: () {
                  setState(() {
                    _monthlyController.text = val.toString();
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // META SEMANAL
          const Text('Meta Semanal (€):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _weeklyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixText: '€ / semana',
              suffixStyle: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
              prefixIcon: const Icon(Icons.calendar_view_week, color: AppTheme.accentGreen),
              filled: true,
              fillColor: AppTheme.darkSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          // CHIPS RÁPIDOS SEMANA
          Wrap(
            spacing: 8,
            children: [400, 500, 600, 750].map((val) {
              return ActionChip(
                label: Text('$val €'),
                labelStyle: TextStyle(
                  color: _weeklyController.text == val.toString() ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                backgroundColor: _weeklyController.text == val.toString() ? AppTheme.accentGreen : AppTheme.darkSurface,
                onPressed: () {
                  setState(() {
                    _weeklyController.text = val.toString();
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // FOLGAS E DIAS DE CONDUÇÃO
          const Text('Ritmo de Trabalho Semanal:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildWorkDaysChip(5, '5 dias (2 folgas)'),
              const SizedBox(width: 8),
              _buildWorkDaysChip(6, '6 dias (1 folga)'),
              const SizedBox(width: 8),
              _buildWorkDaysChip(7, '7 dias (sem folga)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryElectric.withOpacity(0.18) : AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryElectric : AppTheme.darkBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.primaryElectric : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkDaysChip(int days, String label) {
    final selected = _workDaysPerWeek == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _workDaysPerWeek = days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryElectric : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : AppTheme.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
