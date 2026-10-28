import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_shift.dart';
import '../services/assistant_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DailyShift> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    final list = await StorageService.loadShifts();
    setState(() {
      _shifts = list;
      _isLoading = false;
    });
  }

  Future<void> _deleteShift(String id) async {
    await StorageService.deleteShift(id);
    await _loadShifts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Turno eliminado.'), backgroundColor: AppTheme.dangerRed),
    );
  }

  Future<void> _exportCurrentMonthPdf() async {
    final now = DateTime.now();
    final monthShifts = _shifts.where((s) => s.date.year == now.year && s.date.month == now.month).toList();
    if (monthShifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não existem turnos registados para o mês atual.'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    monthShifts.sort((a, b) => a.date.compareTo(b.date));

    final totalGross = monthShifts.fold<double>(0.0, (sum, s) => sum + s.totalGross);
    final uberGross = monthShifts.fold<double>(0.0, (sum, s) => sum + s.uberGross);
    final boltGross = monthShifts.fold<double>(0.0, (sum, s) => sum + s.boltGross);
    final tips = monthShifts.fold<double>(0.0, (sum, s) => sum + s.tips);
    final platformFees = monthShifts.fold<double>(0.0, (sum, s) => sum + s.platformFeeAmount);
    final chargingCost = monthShifts.fold<double>(0.0, (sum, s) => sum + s.chargingCost);
    final chargingKwh = monthShifts.fold<double>(0.0, (sum, s) => sum + s.chargingKwh);
    final tollsCost = monthShifts.fold<double>(0.0, (sum, s) => sum + s.tollsCost);
    final otherExpenses = monthShifts.fold<double>(0.0, (sum, s) => sum + s.otherExpenses);
    final totalExpenses = monthShifts.fold<double>(0.0, (sum, s) => sum + s.totalExpenses);
    final netProfit = monthShifts.fold<double>(0.0, (sum, s) => sum + s.netProfit);
    final totalKm = monthShifts.fold<double>(0.0, (sum, s) => sum + s.totalKm);
    final totalHours = monthShifts.fold<double>(0.0, (sum, s) => sum + s.hoursWorked);
    final profitPerKm = totalKm > 0 ? (netProfit / totalKm) : 0.0;
    final profitPerHour = totalHours > 0 ? (netProfit / totalHours) : 0.0;

    const ptMonths = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final monthName = '${ptMonths[now.month - 1]} ${now.year}';

    final shiftsData = monthShifts.map((s) {
      final dayStr = '${s.date.day.toString().padLeft(2, '0')}/${s.date.month.toString().padLeft(2, '0')}';
      return {
        'date': dayStr,
        'uber': s.uberGross,
        'bolt': s.boltGross,
        'gross': s.totalGross,
        'km': s.totalKm,
        'hours': s.hoursWorked,
        'charging': s.chargingCost,
        'tolls': s.tollsCost,
        'net': s.netProfit,
      };
    }).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('A gerar PDF mensal de $monthName...'),
        backgroundColor: AppTheme.primaryElectric,
        duration: const Duration(seconds: 2),
      ),
    );

    await AssistantService.exportMonthlyPdf(
      monthName: monthName,
      month: now.month,
      year: now.year,
      totalGross: totalGross,
      uberGross: uberGross,
      boltGross: boltGross,
      tips: tips,
      platformFees: platformFees,
      chargingCost: chargingCost,
      chargingKwh: chargingKwh,
      tollsCost: tollsCost,
      otherExpenses: otherExpenses,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      totalKm: totalKm,
      totalHours: totalHours,
      profitPerKm: profitPerKm,
      profitPerHour: profitPerHour,
      shifts: shiftsData,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryElectric)),
      );
    }

    final totalNetProfit = _shifts.fold<double>(0.0, (sum, s) => sum + s.netProfit);
    final totalGross = _shifts.fold<double>(0.0, (sum, s) => sum + s.totalGross);
    final totalKm = _shifts.fold<double>(0.0, (sum, s) => sum + s.totalKm);
    final avgProfitPerKm = totalKm > 0 ? (totalNetProfit / totalKm) : 0.0;
    final avgProfitPerDay = _shifts.isNotEmpty ? (totalNetProfit / _shifts.length) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_edu_rounded, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Histórico de Turnos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryElectric),
            tooltip: 'Exportar PDF Mensal',
            onPressed: _exportCurrentMonthPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // RESUMO ACUMULADO
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL ACUMULADO (${_shifts.length} DIAS)',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${totalNetProfit.toStringAsFixed(2)} €',
                      style: const TextStyle(color: AppTheme.accentGreen, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.darkBorder, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHistoryStat('Receita', '${totalGross.toStringAsFixed(0)} €'),
                    _buildHistoryStat('Km Totais', '${totalKm.toStringAsFixed(0)} km'),
                    _buildHistoryStat('Média / Dia', '${avgProfitPerDay.toStringAsFixed(1)} €'),
                    _buildHistoryStat('Média / km', '${avgProfitPerKm.toStringAsFixed(2)} €'),
                  ],
                ),
              ],
            ),
          ),

          // LISTA DE TURNOS
          Expanded(
            child: _shifts.isEmpty
                ? const Center(
                    child: Text(
                      'Ainda não guardaste nenhum turno.\nRegista o teu dia no separador "Fecho do Dia"!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, height: 1.5),
                    ),
                  )
                : ListView.builder(
                    itemCount: _shifts.length,
                    itemBuilder: (context, index) {
                      final s = _shifts[index];
                      final dateFormat = DateFormat('dd/MM/yyyy (EEE)');
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryElectric),
                                      const SizedBox(width: 6),
                                      Text(
                                        dateFormat.format(s.date),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '+${s.netProfit.toStringAsFixed(2)} €',
                                        style: const TextStyle(
                                          color: AppTheme.accentGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textMuted),
                                        onPressed: () => _deleteShift(s.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(color: AppTheme.darkBorder, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    s.driverEarnings > 0
                                        ? 'Ganho: ${s.driverEarnings.toStringAsFixed(2)} € ${s.tips > 0 ? "| Gorjetas: +${s.tips.toStringAsFixed(2)} €" : ""}'
                                        : 'Uber: ${s.uberGross.toStringAsFixed(0)}€ | Bolt: ${s.boltGross.toStringAsFixed(0)}€ | Gorjetas: ${s.tips.toStringAsFixed(1)}€',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                  ),
                                  Text(
                                    '${s.profitPerKm.toStringAsFixed(2)} €/km',
                                    style: const TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${s.totalKm.toStringAsFixed(0)} km em ${s.hoursWorked.toStringAsFixed(1)}h (${s.profitPerHour.toStringAsFixed(1)} €/h)',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                  ),
                                  Text(
                                    'Carga: ${s.chargingCost.toStringAsFixed(1)}€',
                                    style: const TextStyle(color: AppTheme.warningAmber, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
      ],
    );
  }
}
