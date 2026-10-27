import 'package:flutter/material.dart';

class AppTheme {
  // Cores Principais - Tema Dark Otimizado para Condutores TVDE (ecrãs OLED/carro)
  static const Color primaryElectric = Color(0xFF00E5FF); // Azul Elétrico Neon
  static const Color accentGreen = Color(0xFF00E676);    // Verde Lucro Alto
  static const Color warningAmber = Color(0xFFFFB300);   // Âmbar Margem Média
  static const Color dangerRed = Color(0xFFFF3D00);      // Vermelho Prejuízo
  
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900 profundo
  static const Color darkSurface = Color(0xFF1E293B);    // Slate 800
  static const Color darkCard = Color(0xFF1E293B);       // Cartão elevado
  static const Color darkBorder = Color(0xFF334155);     // Linhas de separação
  static const Color textPrimary = Color(0xFFF8FAFC);    // Branco suave
  static const Color textMuted = Color(0xFF94A3B8);      // Cinzento legível

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryElectric,
        secondary: accentGreen,
        surface: darkSurface,
        error: dangerRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: primaryElectric),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0B132B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryElectric, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryElectric,
          foregroundColor: Colors.black,
          elevation: 3,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryElectric,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
    );
  }
}
