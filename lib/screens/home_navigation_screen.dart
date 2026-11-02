import 'package:flutter/material.dart';
import '../services/assistant_service.dart';
import '../services/buddy_safety_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'trip_calculator_screen.dart';
import 'driving_hours_screen.dart';
import 'charging_stations_screen.dart';
import 'profit_calendar_screen.dart';
import 'settings_screen.dart';
import 'safety_buddies_screen.dart';

class HomeNavigationScreen extends StatefulWidget {
  const HomeNavigationScreen({super.key});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TripCalculatorScreen(),
    DrivingHoursScreen(),
    ChargingStationsScreen(),
    ProfitCalendarScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    BuddySafetyService.updatesNotifier.addListener(_onSafetyUpdate);
    BuddySafetyService.loadConfig();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdatesOnLaunch();
    });
  }

  @override
  void dispose() {
    BuddySafetyService.updatesNotifier.removeListener(_onSafetyUpdate);
    super.dispose();
  }

  void _onSafetyUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkUpdatesOnLaunch() async {
    // Pedir permissões essenciais de Notificações e GPS no arranque
    AssistantService.requestNotificationPermission();
    AssistantService.requestLocationPermission();
  }

  @override
  Widget build(BuildContext context) {
    final incomingSos = BuddySafetyService.activeIncomingSos;
    final isMySos = BuddySafetyService.isMySosActive;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Column(
        children: [
          // BANNER DE ALERTA DE SOS DE COLEGA (SE ATIVO)
          if (incomingSos != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                bottom: 8,
                left: 14,
                right: 8,
              ),
              color: AppTheme.dangerRed,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyBuddiesScreen()));
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🚨 SOS: ${incomingSos.name} precisa de apoio!',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Toca para ver detalhes, WhatsApp e histórico',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Botão rápido para GPS
                  ElevatedButton(
                    onPressed: () => AssistantService.openUrl(incomingSos.googleMapsUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('🧭 GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  // Botão para fechar o banner
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    tooltip: 'Dispensar Alerta',
                    onPressed: () {
                      BuddySafetyService.clearActiveIncomingSos();
                    },
                  ),
                ],
              ),
            ),

          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyBuddiesScreen()));
        },
        backgroundColor: isMySos ? AppTheme.dangerRed : const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isMySos ? AppTheme.dangerRed : AppTheme.primaryElectric.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        tooltip: 'Segurança & SOS Colegas',
        child: Icon(
          Icons.shield,
          color: isMySos ? Colors.white : AppTheme.primaryElectric,
          size: 20,
        ),
      ),
      bottomNavigationBar: isLandscape
          ? SizedBox(
              height: 52,
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                iconSize: 20,
                selectedFontSize: 11,
                unselectedFontSize: 10,
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calculate_outlined),
                    activeIcon: Icon(Icons.calculate),
                    label: 'Calculadora',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.timer_outlined),
                    activeIcon: Icon(Icons.timer),
                    label: 'Horas TVDE',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.ev_station_outlined),
                    activeIcon: Icon(Icons.ev_station),
                    label: 'Postos VE',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_outlined),
                    activeIcon: Icon(Icons.calendar_month),
                    label: 'Lucros & Mês',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Definições',
                  ),
                ],
              ),
            )
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.calculate_outlined),
                  activeIcon: Icon(Icons.calculate),
                  label: 'Calculadora',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.timer_outlined),
                  activeIcon: Icon(Icons.timer),
                  label: 'Horas TVDE',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.ev_station_outlined),
                  activeIcon: Icon(Icons.ev_station),
                  label: 'Postos VE',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Lucros & Mês',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Definições',
                ),
              ],
            ),
    );
  }
}
