import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class AuthRegisterScreen extends StatefulWidget {
  final VoidCallback onRegistered;

  const AuthRegisterScreen({super.key, required this.onRegistered});

  @override
  State<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends State<AuthRegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _enableBiometrics = true;
  bool _canUseBiometrics = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final can = await AuthService.canUseBiometrics();
    if (mounted) {
      setState(() {
        _canUseBiometrics = can;
        _enableBiometrics = can;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim().toLowerCase();
    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Por favor insere um endereço de email válido.');
      return;
    }

    if (pass.length < 4) {
      setState(() => _errorMessage = 'A palavra-passe deve ter pelo menos 4 caracteres.');
      return;
    }

    if (pass != confirm) {
      setState(() => _errorMessage = 'As palavras-passe não coincidem.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthService.setupCredentials(
      email: email,
      password: pass,
      enableLock: true,
    );

    if (success) {
      if (_canUseBiometrics) {
        await AuthService.setBiometricsEnabled(_enableBiometrics);
      }
      widget.onRegistered();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao guardar dados. Tenta novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone e Logotipo
                Container(
                  width: 86,
                  height: 86,
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
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppTheme.primaryElectric,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Bem-vindo ao VoltDrive',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Configuração da Conta do Motorista (1º Acesso)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),

                // Crachá de Versão
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryElectric.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: AppTheme.primaryElectric, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Versão v${UpdateService.currentVersion}',
                        style: const TextStyle(
                          color: AppTheme.primaryElectric,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Formulário de Registo e Associação
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cria as tuas credenciais de acesso seguro:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'O teu email será associado a todos os teus registos, lucros e recuperação de palavra-passe.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 18),

                      // Campo Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Email do Motorista',
                          labelStyle: const TextStyle(color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryElectric),
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Campo Palavra-passe
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Palavra-passe de Acesso',
                          labelStyle: const TextStyle(color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.accentGreen),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Confirmar Palavra-passe
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Confirmar Palavra-passe',
                          labelStyle: const TextStyle(color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      // Opção Biometria
                      if (_canUseBiometrics) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryElectric, size: 22),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Permitir Desbloqueio com Digital / Facial',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Switch(
                                value: _enableBiometrics,
                                activeColor: AppTheme.accentGreen,
                                onChanged: (val) => setState(() => _enableBiometrics = val),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.dangerRed.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Botão Submeter
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleSubmit,
                          icon: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, color: Colors.black),
                          label: Text(
                            _isLoading ? 'A configurar...' : 'Guardar Credenciais & Entrar',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      'VoltDrive v${UpdateService.currentVersion} • Renault Zoe Z.E. 50 Edition',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
