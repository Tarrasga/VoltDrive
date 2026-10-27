import 'package:flutter/material.dart';
import '../services/buddy_safety_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'trip_calculator_screen.dart';
import 'driving_hours_screen.dart';
import 'charging_stations_screen.dart';
import 'daily_shift_screen.dart';
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
    DailyShiftScreen(),
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
    final update = await UpdateService.checkForUpdate();
    if (mounted && update != null && update.hasUpdate) {
      UpdateService.showUpdateDialog(context, update);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomingSos = BuddySafetyService.activeIncomingSos;
    final isMySos = BuddySafetyService.isMySosActive;

    return Scaffold(
      body: Column(
        children: [
          // BANNER DE ALERTA DE SOS DE COLEGA (SE ATIVO)
          if (incomingSos != null)
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyBuddiesScreen()));
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 6,
                  bottom: 8,
                  left: 16,
                  right: 16,
                ),
                color: AppTheme.dangerRed,
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🚨 SOS DE COLEGA: ${incomingSos.name} precisa de apoio!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Text('VER ➔', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
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
      bottomNavigationBar: BottomNavigationBar(
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
            icon: Icon(Icons.query_stats_outlined),
            activeIcon: Icon(Icons.query_stats),
            label: 'Fecho do Dia',
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
