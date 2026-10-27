import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth_lock_screen.dart';
import 'screens/home_navigation_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bloquear orientação para vertical para melhor experiência no suporte do carro
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Estilizar a barra de navegação e barra de status do Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inicializar serviço de autenticação e proteção de dados
  await AuthService.init();

  runApp(const VoltDriveApp());
}

class VoltDriveApp extends StatefulWidget {
  const VoltDriveApp({super.key});

  @override
  State<VoltDriveApp> createState() => _VoltDriveAppState();
}

class _VoltDriveAppState extends State<VoltDriveApp> {
  @override
  void initState() {
    super.initState();
    AuthService.authStateNotifier.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    AuthService.authStateNotifier.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showLock = AuthService.isLockEnabled && !AuthService.isUnlocked;

    return MaterialApp(
      title: 'VoltDrive - TVDE VE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: showLock
          ? AuthLockScreen(onUnlocked: () => setState(() {}))
          : const HomeNavigationScreen(),
    );
  }
}
