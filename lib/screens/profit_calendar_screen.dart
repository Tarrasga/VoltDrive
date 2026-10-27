import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_shift.dart';
import '../models/vehicle_profile.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

enum CalendarViewType { month, week, day }

class ProfitCalendarScreen extends StatefulWidget {
  const ProfitCalendarScreen({super.key});

  @override
  State<ProfitCalendarScreen> createState() => _ProfitCalendarScreenState();
}

class _ProfitCalendarScreenState extends State<ProfitCalendarScreen> {
  CalendarViewType _viewType = CalendarViewType.month;
  DateTime _selectedDate = DateTime.now();
  List<DailyShift> _allShifts = [];
  VehicleProfile _profile = VehicleProfile();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shifts = await StorageService.loadShifts();
    final prof = await StorageService.loadVehicleProfile();
    if (mounted) {
      setState(() {
        _allShifts = shifts;
        _profile = prof;
        _isLoading = false;
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DailyShift? _getShiftForDate(DateTime date) {
    try {
      return _allShifts.firstWhere((s) => _isSameDay(s.date, date));
    } catch (_) {
      return null;
    }
  }

  List<DailyShift> _getShiftsForCurrentMonth() {
    return _allShifts.where((s) => s.date.year == _selectedDate.year && s.date.month == _selectedDate.month).toList();
  }

  List<DailyShift> _getShiftsForCurrentWeek() {
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 7));
    return _allShifts.where((s) => s.date.isAfter(start.subtract(const Duration(seconds: 1))) && s.date.isBefore(end)).toList();
  }

  void _previousPeriod() {
    setState(() {
      if (_viewType == CalendarViewType.month) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      } else if (_viewType == CalendarViewType.week) {
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
      } else {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_viewType == CalendarViewType.month) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      } else if (_viewType == CalendarViewType.week) {
        _selectedDate = _selectedDate.add(const Duration(days: 7));
      } else {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      }
    });
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
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
            Icon(Icons.calendar_month, color: AppTheme.primaryElectric),
            SizedBox(width: 8),
            Text('Calendário de Lucros'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 16, color: AppTheme.primaryElectric),
            label: const Text('Hoje', style: TextStyle(color: AppTheme.primaryElectric, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // SELETOR DE VISTA: [ MÊS | SEMANA | DIA ]
          _buildViewSelector(),

          // NAVEGADOR DE DATAS COM SETAS
          _buildDateNavigator(),

          // CONTEÚDO DINÂMICO CONFORME A VISTA
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: _buildCurrentView(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openShiftFormDialog(date: _selectedDate),
        backgroundColor: AppTheme.accentGreen,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Registar Turno',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==========================================
  // SELETORES E CABEÇALHOS
  // ==========================================

  Widget _buildViewSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          _buildSegmentButton('MÊS', CalendarViewType.month, Icons.calendar_view_month),
          _buildSegmentButton('SEMANA', CalendarViewType.week, Icons.view_week_outlined),
          _buildSegmentButton('DIA', CalendarViewType.day, Icons.calendar_view_day),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, CalendarViewType type, IconData icon) {
    final isSelected = _viewType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryElectric : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.black : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator() {
    String title = '';
    if (_viewType == CalendarViewType.month) {
      final monthsPt = [
        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
      ];
      title = '${monthsPt[_selectedDate.month - 1]} ${_selectedDate.year}';
    } else if (_viewType == CalendarViewType.week) {
      final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      title = '${monday.day}/${monday.month} a ${sunday.day}/${sunday.month} (${_selectedDate.year})';
    } else {
      final weekdaysPt = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
      title = '${weekdaysPt[_selectedDate.weekday - 1]}, ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.primaryElectric, size: 28),
            onPressed: _previousPeriod,
            tooltip: 'Anterior',
          ),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.primaryElectric, size: 28),
            onPressed: _nextPeriod,
            tooltip: 'Seguinte',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_viewType) {
      case CalendarViewType.month:
        return _buildMonthView();
      case CalendarViewType.week:
        return _buildWeekView();
      case CalendarViewType.day:
        return _buildDayView();
    }
  }

  // ==========================================
  // 1. VISTA MENSAL (CALENDÁRIO COM GRELHA)
  // ==========================================

  Widget _buildMonthView() {
    final monthShifts = _getShiftsForCurrentMonth();
    final totalNet = monthShifts.fold<double>(0.0, (sum, s) => sum + s.netProfit);
    final totalGross = monthShifts.fold<double>(0.0, (sum, s) => sum + s.totalGross);
    final totalKm = monthShifts.fold<double>(0.0, (sum, s) => sum + s.totalKm);
    final totalCharging = monthShifts.fold<double>(0.0, (sum, s) => sum + s.chargingCost);
    final totalHours = monthShifts.fold<double>(0.0, (sum, s) => sum + s.hoursWorked);
    final daysWorked = monthShifts.length;
    final avgNetPerDay = daysWorked > 0 ? (totalNet / daysWorked) : 0.0;
    final avgNetPerKm = totalKm > 0 ? (totalNet / totalKm) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // RESUMO DO MÊS (CARDS)
        Container(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LUCRO LÍQUIDO DO MÊS', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '+${totalNet.toStringAsFixed(2)} €',
                        style: const TextStyle(color: AppTheme.accentGreen, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$daysWorked DIAS TRABALHADOS',
                      style: const TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(color: AppTheme.darkBorder, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Bruto Total', '${totalGross.toStringAsFixed(0)} €'),
                  _buildStatItem('Custo Zoe', '-${totalCharging.toStringAsFixed(0)} €', isCost: true),
                  _buildStatItem('Km Totais', '${totalKm.toStringAsFixed(0)} km'),
                  _buildStatItem('Média / Dia', '${avgNetPerDay.toStringAsFixed(0)} €'),
                  _buildStatItem('Média / Km', '${avgNetPerKm.toStringAsFixed(2)} €'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // GRELHA DO CALENDÁRIO
        _buildCalendarGrid(),

        const SizedBox(height: 70), // Espaço para FAB
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Seg, 7 = Dom
    final today = DateTime.now();

    final weekHeaders = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          // CABEÇALHO DOS DIAS DA SEMANA
          Row(
            children: weekHeaders.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 8),

          // DIAS EM GRELHA
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 semanas max
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - (startingWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox.shrink(); // Espaço vazio antes ou depois
              }

              final dayNumber = dayOffset + 1;
              final cellDate = DateTime(year, month, dayNumber);
              final isToday = _isSameDay(cellDate, today);
              final shift = _getShiftForDate(cellDate);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                  });
                  _showDayDetailsBottomSheet(cellDate, shift);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: shift != null
                        ? (shift.netProfit >= 100
                            ? AppTheme.accentGreen.withOpacity(0.18)
                            : (shift.netProfit > 0
                                ? AppTheme.primaryElectric.withOpacity(0.12)
                                : AppTheme.dangerRed.withOpacity(0.15)))
                        : AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? AppTheme.primaryElectric
                          : (shift != null
                              ? (shift.netProfit >= 100 ? AppTheme.accentGreen.withOpacity(0.6) : AppTheme.darkBorder)
                              : Colors.transparent),
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? AppTheme.primaryElectric : Colors.white,
                        ),
                      ),
                      if (shift != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '+${shift.netProfit.toStringAsFixed(0)}€',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: shift.netProfit >= 100
                                ? AppTheme.accentGreen
                                : (shift.netProfit > 0 ? AppTheme.primaryElectric : AppTheme.dangerRed),
                          ),
                        ),
                        Text(
                          '${shift.totalKm.toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 8, color: AppTheme.textMuted),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        const Text('•', style: TextStyle(color: Colors.white24, fontSize: 10)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. VISTA SEMANAL
  // ==========================================

  Widget _buildWeekView() {
    final weekShifts = _getShiftsForCurrentWeek();
    final totalNet = weekShifts.fold<double>(0.0, (sum, s) => sum + s.netProfit);
    final totalGross = weekShifts.fold<double>(0.0, (sum, s) => sum + s.totalGross);
    final totalKm = weekShifts.fold<double>(0.0, (sum, s) => sum + s.totalKm);
    final totalHours = weekShifts.fold<double>(0.0, (sum, s) => sum + s.hoursWorked);
    final totalCharging = weekShifts.fold<double>(0.0, (sum, s) => sum + s.chargingCost);

    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // RESUMO DA SEMANA
        Container(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LUCRO LÍQUIDO DA SEMANA', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '+${totalNet.toStringAsFixed(2)} €',
                        style: const TextStyle(color: AppTheme.accentGreen, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${totalHours.toStringAsFixed(1)}h / 50h TVDE',
                        style: TextStyle(
                          color: totalHours >= 45 ? AppTheme.warningAmber : AppTheme.primaryElectric,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weekShifts.length} de 7 dias rodados',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Barra de Horas TVDE da Semana
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (totalHours / 50.0).clamp(0.0, 1.0),
                  backgroundColor: AppTheme.darkSurface,
                  color: totalHours >= 45 ? AppTheme.dangerRed : AppTheme.primaryElectric,
                  minHeight: 6,
                ),
              ),
              const Divider(color: AppTheme.darkBorder, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Bruto', '${totalGross.toStringAsFixed(0)} €'),
                  _buildStatItem('Custo Zoe', '-${totalCharging.toStringAsFixed(0)} €', isCost: true),
                  _buildStatItem('Km Rodados', '${totalKm.toStringAsFixed(0)} km'),
                  _buildStatItem('Média / Hora', totalHours > 0 ? '${(totalNet / totalHours).toStringAsFixed(1)} €/h' : '--'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // LISTA DOS 7 DIAS DA SEMANA
        ...List.generate(7, (i) {
          final dayDate = monday.add(Duration(days: i));
          final shift = _getShiftForDate(dayDate);
          final weekdaysPt = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
          final isToday = _isSameDay(dayDate, DateTime.now());

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday
                    ? AppTheme.primaryElectric
                    : (shift != null ? AppTheme.darkBorder : Colors.transparent),
                width: isToday ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday ? AppTheme.primaryElectric : AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${dayDate.day}',
                        style: TextStyle(
                          color: isToday ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${dayDate.month}',
                        style: TextStyle(
                          color: isToday ? Colors.black : AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(weekdaysPt[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: AppTheme.primaryElectric, borderRadius: BorderRadius.circular(4)),
                              child: const Text('HOJE', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (shift != null)
                        Text(
                          'Bruto: ${shift.totalGross.toStringAsFixed(0)}€ • Zoe: -${shift.chargingCost.toStringAsFixed(0)}€ • ${shift.totalKm.toStringAsFixed(0)} km (${shift.hoursWorked.toStringAsFixed(1)}h)',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        )
                      else
                        const Text('Dia de descanso / Folga', style: TextStyle(color: Colors.white30, fontSize: 11)),
                    ],
                  ),
                ),
                if (shift != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${shift.netProfit.toStringAsFixed(2)} €',
                        style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${shift.profitPerKm.toStringAsFixed(2)} €/km',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onPressed: () => _showDayDetailsBottomSheet(dayDate, shift),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () => _openShiftFormDialog(date: dayDate),
                    icon: const Icon(Icons.add, size: 14, color: AppTheme.primaryElectric),
                    label: const Text('Registar', style: TextStyle(fontSize: 11, color: AppTheme.primaryElectric)),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 70),
      ],
    );
  }

  // ==========================================
  // 3. VISTA DIÁRIA
  // ==========================================

  Widget _buildDayView() {
    final shift = _getShiftForDate(_selectedDate);

    if (shift == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.nightlight_round, size: 54, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text(
                'Nenhum turno registado neste dia',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Folga ou turno ainda por registar.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openShiftFormDialog(date: _selectedDate),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Registar Fecho deste Dia', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO CARD DO DIA
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.accentGreen, width: 1.5),
            boxShadow: [
              BoxShadow(color: AppTheme.accentGreen.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              const Text('LUCRO LÍQUIDO LIMPO', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                '+${shift.netProfit.toStringAsFixed(2)} €',
                style: const TextStyle(color: AppTheme.accentGreen, fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('€ / km Líquido', '${shift.profitPerKm.toStringAsFixed(2)} €/km'),
                  _buildStatItem('€ / Hora', '${shift.profitPerHour.toStringAsFixed(2)} €/h'),
                  _buildStatItem('Horas TVDE', '${shift.hoursWorked.toStringAsFixed(1)} h'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // FATURAÇÃO BRUTA
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.payments_outlined, color: AppTheme.primaryElectric, size: 20),
                  SizedBox(width: 8),
                  Text('Faturação das Plataformas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const Divider(color: AppTheme.darkBorder, height: 18),
              _buildDetailRow('Uber Driver (Bruto)', '${shift.uberGross.toStringAsFixed(2)} €'),
              _buildDetailRow('Bolt Driver (Bruto)', '${shift.boltGross.toStringAsFixed(2)} €'),
              _buildDetailRow('Gorjetas Recebidas (100% tuas)', '+${shift.tips.toStringAsFixed(2)} €', color: AppTheme.accentGreen),
              const Divider(color: AppTheme.darkBorder, height: 18),
              _buildDetailRow('Faturação Bruta Total', '${shift.totalGross.toStringAsFixed(2)} €', isBold: true),
              _buildDetailRow('Comissão Plataformas (~${shift.platformFeePercent.toStringAsFixed(0)}%)', '-${shift.platformFeeAmount.toStringAsFixed(2)} €', color: AppTheme.dangerRed),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // CUSTOS RENAULT ZOE & DESPESAS
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.ev_station, color: AppTheme.accentGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Custos Renault Zoe & Estrada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const Divider(color: AppTheme.darkBorder, height: 18),
              _buildDetailRow('Carregamento Elétrico', '-${shift.chargingCost.toStringAsFixed(2)} €', color: AppTheme.warningAmber),
              _buildDetailRow('Portagens Via Verde', '-${shift.tollsCost.toStringAsFixed(2)} €'),
              _buildDetailRow('Outras Despesas (lavagem, água)', '-${shift.otherExpenses.toStringAsFixed(2)} €'),
              const Divider(color: AppTheme.darkBorder, height: 18),
              _buildDetailRow('Km Percorridos', '${shift.totalKm.toStringAsFixed(1)} km', isBold: true),
              if (shift.startKm > 0 && shift.endKm > 0)
                _buildDetailRow('Odómetro', '${shift.startKm.toStringAsFixed(0)} km ➔ ${shift.endKm.toStringAsFixed(0)} km'),
              if (shift.chargingKwh > 0)
                _buildDetailRow('Média Consumo Zoe', '${shift.avgKwhPer100Km.toStringAsFixed(1)} kWh/100km'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // BOTÕES DE AÇÃO: EDITAR E APAGAR
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openShiftFormDialog(date: _selectedDate, existingShift: shift),
                icon: const Icon(Icons.edit, size: 16, color: AppTheme.primaryElectric),
                label: const Text('Editar Turno', style: TextStyle(color: AppTheme.primaryElectric)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryElectric)),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed),
              tooltip: 'Eliminar Turno',
              onPressed: () => _confirmDeleteShift(shift),
            ),
          ],
        ),

        const SizedBox(height: 70),
      ],
    );
  }

  // ==========================================
  // MODAL DE DETALHES RÁPIDOS DO DIA
  // ==========================================

  void _showDayDetailsBottomSheet(DateTime date, DailyShift? shift) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (shift != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LUCRO LÍQUIDO', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('+${shift.netProfit.toStringAsFixed(2)} €', style: const TextStyle(color: AppTheme.accentGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${shift.totalGross.toStringAsFixed(0)} € Bruto', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('${shift.totalKm.toStringAsFixed(0)} km (${shift.profitPerKm.toStringAsFixed(2)} €/km)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openShiftFormDialog(date: date, existingShift: shift);
                      },
                      icon: const Icon(Icons.edit, size: 16, color: AppTheme.primaryElectric),
                      label: const Text('Editar', style: TextStyle(color: AppTheme.primaryElectric)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryElectric)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _viewType = CalendarViewType.day;
                          _selectedDate = date;
                        });
                      },
                      icon: const Icon(Icons.visibility, size: 16, color: Colors.black),
                      label: const Text('Ver Tudo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text('Nenhum turno registado neste dia (Folga).', style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openShiftFormDialog(date: date);
                },
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Registar Turno deste Dia', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FORMULÁRIO DE REGISTO / EDIÇÃO DE TURNO
  // ==========================================

  void _openShiftFormDialog({required DateTime date, DailyShift? existingShift}) {
    final uberCtrl = TextEditingController(text: existingShift?.uberGross.toStringAsFixed(2) ?? '95.00');
    final boltCtrl = TextEditingController(text: existingShift?.boltGross.toStringAsFixed(2) ?? '80.00');
    final tipsCtrl = TextEditingController(text: existingShift?.tips.toStringAsFixed(2) ?? '8.50');
    final startKmCtrl = TextEditingController(text: existingShift != null && existingShift.startKm > 0 ? existingShift.startKm.toStringAsFixed(0) : '124500');
    final endKmCtrl = TextEditingController(text: existingShift != null && existingShift.endKm > 0 ? existingShift.endKm.toStringAsFixed(0) : '124710');
    final kmCtrl = TextEditingController(text: existingShift?.totalKm.toStringAsFixed(1) ?? '210.0');
    final hoursCtrl = TextEditingController(text: existingShift?.hoursWorked.toStringAsFixed(1) ?? '8.5');
    final chargingCtrl = TextEditingController(text: existingShift?.chargingCost.toStringAsFixed(2) ?? '12.50');
    final tollsCtrl = TextEditingController(text: existingShift?.tollsCost.toStringAsFixed(2) ?? '4.20');
    final othersCtrl = TextEditingController(text: existingShift?.otherExpenses.toStringAsFixed(2) ?? '2.50');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setModalState) {
          double parseVal(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;

          final uber = parseVal(uberCtrl);
          final bolt = parseVal(boltCtrl);
          final tips = parseVal(tipsCtrl);
          final startKm = parseVal(startKmCtrl);
          final endKm = parseVal(endKmCtrl);
          final km = (endKm > startKm && startKm > 0) ? (endKm - startKm) : parseVal(kmCtrl);
          final charging = parseVal(chargingCtrl);
          final tolls = parseVal(tollsCtrl);
          final others = parseVal(othersCtrl);

          final platformFee = _profile.platformFeePercent / 100.0;
          final netRevenue = ((uber + bolt) * (1.0 - platformFee)) + tips;
          final totalCosts = charging + tolls + others;
          final estNetProfit = netRevenue - totalCosts;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(dlgCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_calendar, color: AppTheme.primaryElectric, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Registo do Turno (${date.day}/${date.month}/${date.year})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(dlgCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // FATURAÇÃO BRUTA
                  const Text('1. Faturação Bruta das Plataformas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryElectric)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: uberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Uber (€)', prefixIcon: Icon(Icons.directions_car, size: 16)),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: boltCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Bolt (€)', prefixIcon: Icon(Icons.bolt, size: 16, color: Color(0xFF00D665))),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: tipsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Gorjetas (€)', prefixIcon: Icon(Icons.favorite, size: 16, color: AppTheme.accentGreen)),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // QUILÓMETROS & HORAS
                  const Text('2. Quilómetros & Horas de Condução', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryElectric)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startKmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Km Iniciais', hintText: '124500'),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: endKmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Km Finais', hintText: '124710'),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hoursCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Horas (h)', hintText: '8.5'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // CUSTOS RENAULT ZOE & DESPESAS
                  const Text('3. Custos Renault Zoe & Despesas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryElectric)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: chargingCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Carregamento (€)', prefixIcon: Icon(Icons.ev_station, size: 16, color: AppTheme.accentGreen)),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: tollsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Portagens (€)', prefixIcon: Icon(Icons.toll, size: 16)),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: othersCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Outros (€)', prefixIcon: Icon(Icons.receipt_long, size: 16)),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // RESUMO DO LUCRO PREVISTO
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LUCRO LÍQUIDO CALCULADO:', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(
                              '+${estNetProfit.toStringAsFixed(2)} €',
                              style: const TextStyle(color: AppTheme.accentGreen, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${km.toStringAsFixed(0)} km  •  ${km > 0 ? (estNetProfit / km).toStringAsFixed(2) : '0.00'} €/km',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BOTÃO DE GUARDAR
                  ElevatedButton(
                    onPressed: () async {
                      final newShift = DailyShift(
                        id: existingShift?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        date: date,
                        uberGross: uber,
                        boltGross: bolt,
                        tips: tips,
                        startKm: startKm,
                        endKm: endKm,
                        totalKm: km,
                        chargingCost: charging,
                        tollsCost: tolls,
                        otherExpenses: others,
                        hoursWorked: parseVal(hoursCtrl),
                        platformFeePercent: _profile.platformFeePercent,
                      );

                      await StorageService.saveShift(newShift);
                      await _loadData();
                      if (mounted) Navigator.pop(dlgCtx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Turno de ${date.day}/${date.month} guardado com sucesso!'),
                          backgroundColor: AppTheme.accentGreen,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Guardar Fecho do Turno', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteShift(DailyShift shift) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Turno?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Tens a certeza que queres eliminar o turno de ${shift.date.day}/${shift.date.month}/${shift.date.year}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.deleteShift(shift.id);
              await _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Turno eliminado.'), backgroundColor: AppTheme.dangerRed),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPERS DE UI
  // ==========================================

  Widget _buildStatItem(String label, String value, {bool isCost = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: isCost ? AppTheme.warningAmber : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.white : AppTheme.textMuted, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}
