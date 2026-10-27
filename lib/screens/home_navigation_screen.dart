import 'package:flutter/material.dart';
import 'trip_calculator_screen.dart';
import 'driving_hours_screen.dart';
import 'charging_stations_screen.dart';
import 'daily_shift_screen.dart';
import 'settings_screen.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
