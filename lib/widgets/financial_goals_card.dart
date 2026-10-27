import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_shift.dart';
import '../models/financial_goals.dart';
import '../screens/financial_goals_screen.dart';
import '../theme/app_theme.dart';

class FinancialGoalsCard extends StatelessWidget {
  final FinancialGoals goals;
  final List<DailyShift> shifts;
  final bool isMonthView;
  final VoidCallback? onGoalsChanged;

  const FinancialGoalsCard({
    super.key,
    required this.goals,
    required this.shifts,
    this.isMonthView = true,
    this.onGoalsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2);
    final calculation = isMonthView
        ? goals.calculateMonthlyPace(shifts)
        : goals.calculateWeeklyPace(shifts);

    final bool reached = calculation.isTargetReached;
    final String title = isMonthView ? 'Meta Mensal' : 'Meta Semanal';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reached ? AppTheme.accentGreen : AppTheme.primaryElectric.withOpacity(0.4),
          width: 1.2,
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
                    reached ? Icons.emoji_events_rounded : Icons.track_changes_rounded,
                    color: reached ? AppTheme.accentGreen : AppTheme.primaryElectric,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  FinancialGoalsScreen.showAsModal(context, shifts: shifts, onSaved: onGoalsChanged);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tune, color: AppTheme.primaryElectric, size: 14),
                      SizedBox(width: 4),
                      Text('Ajustar', style: TextStyle(color: AppTheme.primaryElectric, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // BARRA DE PROGRESSO
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (calculation.percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.darkSurface,
              color: reached ? AppTheme.accentGreen : AppTheme.primaryElectric,
            ),
          ),

          const SizedBox(height: 10),

          // RESUMO E DIVISÃO PELOS DIAS RESTANTES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currencyFormat.format(calculation.achieved)} / ${currencyFormat.format(calculation.target)} (${calculation.percentage.toStringAsFixed(0)}%)',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              if (!reached)
                Text(
                  'Faltam ${calculation.daysLeft} dias',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // BANNER DE RITMO DIÁRIO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: reached ? AppTheme.accentGreen.withOpacity(0.12) : const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  reached ? Icons.check_circle : Icons.trending_up,
                  color: reached ? AppTheme.accentGreen : AppTheme.accentGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reached
                        ? '🎉 Meta atingida! Lucro extra: +${currencyFormat.format(-calculation.remaining)}'
                        : 'Meta diária necessária: ${currencyFormat.format(calculation.requiredDailyPaceCalendar)} / dia',
                    style: TextStyle(
                      color: reached ? AppTheme.accentGreen : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
