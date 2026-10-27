import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth_lock_screen.dart';
import 'screens/auth_register_screen.dart';
import 'screens/home_navigation_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar suporte de formatação e datas em português
  try {
    await initializeDateFormatting('pt_PT', null);
  } catch (_) {}
  
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
    Widget homeScreen;

    if (!AuthService.hasCredentials) {
      // 1º Acesso após instalação: Configurar Email e Palavra-passe do Motorista
      homeScreen = AuthRegisterScreen(
        onRegistered: () => setState(() {}),
      );
    } else if (AuthService.isLockEnabled && !AuthService.isUnlocked) {
      // Acesso bloqueado: Solicitar Biometria (Digital / Facial) ou Palavra-passe
      homeScreen = AuthLockScreen(
        onUnlocked: () => setState(() {}),
      );
    } else {
      // Desbloqueado: Ecrã principal do VoltDrive
      homeScreen = const HomeNavigationScreen();
    }

    return MaterialApp(
      title: 'VoltDrive - TVDE VE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: homeScreen,
    );
  }
}
