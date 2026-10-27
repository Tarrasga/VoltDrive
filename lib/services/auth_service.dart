import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLockEnabled = 'voltdrive_auth_lock_enabled';
  static const String _keyUserEmail = 'voltdrive_auth_user_email';
  static const String _keyPasswordHash = 'voltdrive_auth_password_hash';
  static const String _keyPasswordSalt = 'voltdrive_auth_password_salt';
  static const String _keyRecoveryCode = 'voltdrive_auth_recovery_code';
  static const String _keyRecoveryExpiry = 'voltdrive_auth_recovery_expiry';

  static bool _isLockEnabled = false;
  static String _userEmail = '';
  static String _passwordHash = '';
  static String _passwordSalt = '';
  static bool _isUnlocked = false;

  static ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(false);

  static bool get isLockEnabled => _isLockEnabled;
  static String get userEmail => _userEmail;
  static bool get isUnlocked => _isUnlocked;
  static bool get hasCredentials => _passwordHash.isNotEmpty && _userEmail.isNotEmpty;

  /// Inicializa o serviço e carrega credenciais guardadas
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLockEnabled = prefs.getBool(_keyIsLockEnabled) ?? false;
      _userEmail = prefs.getString(_keyUserEmail) ?? '';
      _passwordHash = prefs.getString(_keyPasswordHash) ?? '';
      _passwordSalt = prefs.getString(_keyPasswordSalt) ?? '';

      // Se o bloqueio não estiver ativo, considera desbloqueado
      if (!_isLockEnabled || !hasCredentials) {
        _isUnlocked = true;
      } else {
        _isUnlocked = false;
      }
      authStateNotifier.value = _isUnlocked;
    } catch (e) {
      debugPrint('Erro ao inicializar AuthService: $e');
    }
  }

  /// Gera um hash SHA-256 seguro com salt
  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt#VD#$password#$salt');
    return sha256.convert(bytes).toString();
  }

  /// Configura ou atualiza credenciais (Email + Palavra-passe)
  static Future<bool> setupCredentials({
    required String email,
    required String password,
    bool enableLock = true,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();

      if (cleanEmail.isEmpty || !cleanEmail.contains('@') || cleanPassword.isEmpty) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final salt = DateTime.now().millisecondsSinceEpoch.toString();
      final hash = _hashPassword(cleanPassword, salt);

      await prefs.setString(_keyUserEmail, cleanEmail);
      await prefs.setString(_keyPasswordHash, hash);
      await prefs.setString(_keyPasswordSalt, salt);
      await prefs.setBool(_keyIsLockEnabled, enableLock);

      _userEmail = cleanEmail;
      _passwordHash = hash;
      _passwordSalt = salt;
      _isLockEnabled = enableLock;
      _isUnlocked = true;

      authStateNotifier.value = _isUnlocked;
      return true;
    } catch (e) {
      debugPrint('Erro ao configurar credenciais: $e');
      return false;
    }
  }

  /// Tenta desbloquear a aplicação com a palavra-passe
  static bool verifyAndUnlock(String password) {
    if (!_isLockEnabled) {
      _isUnlocked = true;
      authStateNotifier.value = true;
      return true;
    }

    final cleanPassword = password.trim();
    final calculatedHash = _hashPassword(cleanPassword, _passwordSalt);

    if (calculatedHash == _passwordHash) {
      _isUnlocked = true;
      authStateNotifier.value = true;
      return true;
    }
    return false;
  }

  /// Ativa ou desativa o bloqueio da aplicação
  static Future<bool> setLockEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLockEnabled, enabled);
      _isLockEnabled = enabled;
      if (!enabled) {
        _isUnlocked = true;
      }
      authStateNotifier.value = _isUnlocked;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bloqueia a aplicação imediatamente
  static void lockApp() {
    if (_isLockEnabled && hasCredentials) {
      _isUnlocked = false;
      authStateNotifier.value = false;
    }
  }

  /// Solicita recuperação de palavra-passe para o email associado
  /// Retorna o código gerado para permitir envio por rede e fallback offline
  static Future<String?> requestPasswordRecovery() async {
    if (_userEmail.isEmpty) return null;

    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString(); // 6 dígitos
    final expiry = DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRecoveryCode, code);
      await prefs.setInt(_keyRecoveryExpiry, expiry);

      // Enviar email via serviço de envio (ntfy com cabeçalho Email)
      _sendRecoveryEmailViaNtfy(_userEmail, code);

      return code;
    } catch (_) {
      return null;
    }
  }

  /// Envia email com o código de recuperação para o motorista
  static Future<void> _sendRecoveryEmailViaNtfy(String email, String code) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(Uri.parse('https://ntfy.sh/voltdrive_recovery'));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Email', email);
      request.headers.set('Title', 'VoltDrive - Codigo de Recuperacao');

      final body = jsonEncode({
        'topic': 'voltdrive_recovery',
        'title': 'Recuperacao de Acesso VoltDrive',
        'message': 'O teu codigo de seguranca para redefinir a palavra-passe do VoltDrive e: $code (Valido por 15 minutos).',
        'email': email,
      });

      request.write(body);
      final response = await request.close();
      await response.drain();
    } catch (_) {
      // Ignora erro de rede, o código fica disponível no ecrã de recuperação como fallback
    }
  }

  /// Valida o código de recuperação e redefine a palavra-passe
  static Future<bool> resetPasswordWithCode({
    required String code,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_keyRecoveryCode);
      final expiry = prefs.getInt(_keyRecoveryExpiry) ?? 0;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (savedCode == null || savedCode != code.trim() || now > expiry) {
        return false;
      }

      // Redefinir password
      final cleanPassword = newPassword.trim();
      final salt = DateTime.now().millisecondsSinceEpoch.toString();
      final hash = _hashPassword(cleanPassword, salt);

      await prefs.setString(_keyPasswordHash, hash);
      await prefs.setString(_keyPasswordSalt, salt);
      await prefs.remove(_keyRecoveryCode);
      await prefs.remove(_keyRecoveryExpiry);

      _passwordHash = hash;
      _passwordSalt = salt;
      _isUnlocked = true;
      authStateNotifier.value = true;

      return true;
    } catch (_) {
      return false;
    }
  }
}
