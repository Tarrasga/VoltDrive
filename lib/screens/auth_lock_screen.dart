import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class AuthLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AuthLockScreen({super.key, required this.onUnlocked});

  @override
  State<AuthLockScreen> createState() => _AuthLockScreenState();
}

class _AuthLockScreenState extends State<AuthLockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  String? _errorMessage;
  bool _isRecovering = false;
  bool _canCheckBiometrics = false;

  // Controladores de Recuperação
  final TextEditingController _recoveryCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String? _sentCodeForOfflineDisplay;
  bool _recoveryCodeSent = false;
  String? _recoveryError;

  @override
  void initState() {
    super.initState();
    _checkAndPromptBiometrics();
  }

  Future<void> _checkAndPromptBiometrics() async {
    final canBio = await AuthService.canUseBiometrics();
    if (mounted) {
      setState(() => _canCheckBiometrics = canBio);
    }
    if (canBio && AuthService.isBiometricsEnabled) {
      // Disparar automaticamente ao abrir o ecrã
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _handleBiometricAuth();
      });
    }
  }

  Future<void> _handleBiometricAuth() async {
    final success = await AuthService.authenticateBiometrics();
    if (success && mounted) {
      widget.onUnlocked();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _recoveryCodeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _handleUnlock() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Por favor insere a tua palavra-passe.');
      return;
    }

    final success = AuthService.verifyAndUnlock(password);
    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'Palavra-passe incorreta. Tenta novamente.';
        _passwordController.clear();
      });
    }
  }

  Future<void> _handleStartRecovery() async {
    final code = await AuthService.requestPasswordRecovery();
    if (code != null) {
      setState(() {
        _recoveryCodeSent = true;
        _sentCodeForOfflineDisplay = code;
        _recoveryError = null;
      });
    } else {
      setState(() {
        _recoveryError = 'Não foi possível gerar código de recuperação.';
      });
    }
  }

  Future<void> _handleConfirmRecovery() async {
    final code = _recoveryCodeController.text.trim();
    final newPass = _newPasswordController.text.trim();

    if (code.isEmpty || code.length != 6) {
      setState(() => _recoveryError = 'Insere o código de 6 dígitos.');
      return;
    }
    if (newPass.length < 4) {
      setState(() => _recoveryError = 'A nova palavra-passe deve ter pelo menos 4 caracteres.');
      return;
    }

    final success = await AuthService.resetPasswordWithCode(
      code: code,
      newPassword: newPass,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Palavra-passe redefinida com sucesso! A entrar...'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
      widget.onUnlocked();
    } else {
      setState(() {
        _recoveryError = 'Código de recuperação inválido ou expirado.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.userEmail;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: _isRecovering ? _buildRecoveryView(email) : _buildLoginView(email),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView(String email) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ícone e Logo
        GestureDetector(
          onTap: _canCheckBiometrics ? _handleBiometricAuth : null,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryElectric.withOpacity(0.12),
              border: Border.all(color: AppTheme.primaryElectric, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryElectric.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _canCheckBiometrics ? Icons.fingerprint_rounded : Icons.lock_rounded,
              color: AppTheme.primaryElectric,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'VoltDrive Seguro',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Renault Zoe Edition • TVDE Protegido',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: AppTheme.primaryElectric, size: 14),
              SizedBox(width: 4),
              Text(
                'Versão v${UpdateService.currentVersion}',
                style: TextStyle(
                  color: AppTheme.primaryElectric,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cartão do Email Associado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, color: AppTheme.primaryElectric, size: 20),
              const SizedBox(width: 8),
              Text(
                email.isNotEmpty ? email : 'Conta do Motorista',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Campo Palavra-passe
        TextField(
          controller: _passwordController,
          obscureText: _obscureText,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onSubmitted: (_) => _handleUnlock(),
          decoration: InputDecoration(
            labelText: 'Palavra-passe de Acesso',
            labelStyle: const TextStyle(color: AppTheme.textMuted),
            prefixIcon: const Icon(Icons.key, color: AppTheme.primaryElectric),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textMuted,
              ),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            filled: true,
            fillColor: AppTheme.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primaryElectric, width: 2),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.dangerRed.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Botão Entrar
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _handleUnlock,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_open_rounded, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'Desbloquear VoltDrive',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botão Desbloqueio Biométrico (Impressão Digital / Facial)
        if (_canCheckBiometrics) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _handleBiometricAuth,
              icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryElectric, size: 24),
              label: const Text(
                'Entrar com Impressão Digital / Facial',
                style: TextStyle(
                  color: AppTheme.primaryElectric,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryElectric, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Link Recuperação
        TextButton.icon(
          onPressed: () {
            setState(() {
              _isRecovering = true;
              _errorMessage = null;
            });
          },
          icon: const Icon(Icons.help_outline, color: AppTheme.primaryElectric, size: 18),
          label: const Text(
            'Esqueceste-te da palavra-passe? Recuperar via Email',
            style: TextStyle(
              color: AppTheme.primaryElectric,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Rodapé de Versão
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 13),
            SizedBox(width: 5),
            Text(
              'VoltDrive v${UpdateService.currentVersion} • Renault Zoe Z.E. 50',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecoveryView(String email) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.warningAmber.withOpacity(0.15),
            border: Border.all(color: AppTheme.warningAmber, width: 2),
          ),
          child: const Icon(Icons.mark_email_read_rounded, color: AppTheme.warningAmber, size: 36),
        ),
        const SizedBox(height: 18),
        const Text(
          'Recuperar Palavra-passe',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Enviamos um código de segurança para o teu email:\n$email',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 20),

        if (!_recoveryCodeSent) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _handleStartRecovery,
              icon: const Icon(Icons.send_rounded, color: Colors.black),
              label: const Text('Enviar Código para o Email', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
            ),
          ),
        ] else ...[
          // Código visível caso esteja offline
          if (_sentCodeForOfflineDisplay != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.primaryElectric, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Código gerado: $_sentCodeForOfflineDisplay\n(Válido por 15 minutos)',
                      style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          TextField(
            controller: _recoveryCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
            decoration: InputDecoration(
              labelText: 'Código de 6 dígitos',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.pin, color: AppTheme.primaryElectric),
              filled: true,
              fillColor: AppTheme.darkCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _newPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nova Palavra-passe',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.lock_reset, color: AppTheme.accentGreen),
              filled: true,
              fillColor: AppTheme.darkCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleConfirmRecovery,
              icon: const Icon(Icons.check_circle_outline, color: Colors.black),
              label: const Text('Redefinir e Entrar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            ),
          ),
        ],

        if (_recoveryError != null) ...[
          const SizedBox(height: 12),
          Text(
            _recoveryError!,
            style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
          ),
        ],

        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _isRecovering = false;
              _recoveryError = null;
            });
          },
          child: const Text('Voltar ao Ecrã de Entrada', style: TextStyle(color: AppTheme.textMuted)),
        ),
        const SizedBox(height: 16),
        const Text(
          'VoltDrive v${UpdateService.currentVersion}',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
