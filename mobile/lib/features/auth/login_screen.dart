import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/biometric_lock.dart';
import '../../core/theme/app_theme.dart';
import 'forgot_password_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  // O que a pessoa escolheu no interruptor nesta visita. Nulo = acompanha o que
  // esta salvo no aparelho (ha credencial guardada = biometria ligada).
  bool? _biometricChoice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool enableBiometric = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Confirma a biometria antes de logar, pra não entrar numa sessão
      // quando a pessoa cancelou a ativação.
      if (enableBiometric &&
          !await ref.read(biometricLockProvider.notifier).authenticate('Confirme para ativar o acesso por biometria')) {
        setState(() => _errorMessage = 'Não foi possível confirmar sua identidade.');
        return;
      }
      await ref.read(sessionProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            enableBiometric: enableBiometric,
          );
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Ligado: se ja ha credencial guardada, o botao pede a biometria e entra, sem
  // digitar nada; se e a primeira vez, entra com e-mail e senha e deixa a
  // biometria ativada para as proximas. Desligado: e-mail e senha, como sempre.
  Future<void> _enter(bool biometricOn, bool biometricSaved) {
    if (biometricOn && biometricSaved) return _submitWithBiometrics();
    return _submit(enableBiometric: biometricOn);
  }

  // Desligar apaga a credencial guardada: o aparelho volta a pedir e-mail e
  // senha, e o app deixa de abrir trancado pela biometria.
  Future<void> _toggleBiometric(bool value, bool biometricSaved) async {
    setState(() {
      _biometricChoice = value;
      _errorMessage = null;
    });
    if (!value && biometricSaved) {
      await ref.read(biometricLockProvider.notifier).disable();
    }
  }

  Future<void> _submitWithBiometrics() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(sessionProvider.notifier).loginWithBiometrics();
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(biometricLockProvider).value?.enabled ?? false;
    final biometricAvailable = ref.watch(biometricAvailableProvider).value ?? false;
    final biometricOn = _biometricChoice ?? biometricEnabled;
    // Com a biometria ja guardada nao ha o que digitar: o botao entra direto.
    final usesSavedBiometric = biometricOn && biometricEnabled;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset('assets/images/logo.png', width: 84, height: 84),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'DSConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entre com o mesmo e-mail e senha que você já usa',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) =>
                                (!usesSavedBiometric && (value == null || value.trim().isEmpty)) ? 'Informe o e-mail' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              // Teclado de celular costuma autocorrigir ou mudar
                              // maiúscula sem avisar - como o texto normalmente fica
                              // escondido, um erro de digitação passa despercebido.
                              // Poder revelar a senha ajuda a confirmar isso antes
                              // de culpar o servidor.
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                tooltip: _obscurePassword ? 'Mostrar senha' : 'Esconder senha',
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) => (!usesSavedBiometric && (value == null || value.isEmpty)) ? 'Informe a senha' : null,
                            onFieldSubmitted: (_) => _enter(biometricOn, biometricEnabled),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => showForgotPasswordSheet(context, initialEmail: _emailController.text.trim()),
                              child: const Text('Esqueci minha senha'),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (biometricAvailable || biometricEnabled)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(Icons.fingerprint),
                              title: const Text('Entrar com biometria'),
                              value: biometricOn,
                              onChanged: _isSubmitting ? null : (value) => _toggleBiometric(value, biometricEnabled),
                            ),
                          const SizedBox(height: 16),
                          GradientButton(
                            onPressed: _isSubmitting ? null : () => _enter(biometricOn, biometricEnabled),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Entrar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(child: _AppVersionLabel()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Mostra a versão instalada - a forma mais simples de confirmar, ao abrir o
// app depois de instalar um APK novo, que o build certo chegou no aparelho.
class _AppVersionLabel extends StatelessWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Text(
          'Versão ${info.version}',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
        );
      },
    );
  }
}
