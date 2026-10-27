import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_navigation_screen.dart';
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

  runApp(const VoltDriveApp());
}

class VoltDriveApp extends StatelessWidget {
  const VoltDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoltDrive - TVDE VE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeNavigationScreen(),
    );
  }
}
