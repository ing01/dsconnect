import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_mode.dart';
import 'core/auth/auth_providers.dart';
import 'core/auth/biometric_lock.dart';
import 'core/theme/app_theme.dart';
import 'features/agent/agent_home_shell.dart';
import 'features/auth/account_picker_screen.dart';
import 'features/auth/biometric_lock_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/client/client_home_shell.dart';

class DuedeskApp extends StatelessWidget {
  const DuedeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _RootGate(),
    );
  }
}

// Decide qual tela mostrar conforme o estado da sessão - sem rotas
// nomeadas por enquanto, o app ainda é pequeno o bastante pra isso bastar.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> with WidgetsBindingObserver {
  // Tirar foto ou gravar áudio manda o app pro segundo plano por instantes -
  // só tranca de novo se ficou fora mais que isso.
  static const _relockAfter = Duration(minutes: 1);
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null && DateTime.now().difference(pausedAt) >= _relockAfter) {
        ref.read(biometricLockProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);
    final lockAsync = ref.watch(biometricLockProvider);

    // Sem esperar o estado da trava, a sessão apareceria por um instante
    // antes da tela de biometria.
    if (lockAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Sessão salva veio corrompida/expirada de um jeito que a leitura
      // falhou - trata como deslogado em vez de travar o app numa tela de
      // erro sem saída.
      error: (_, _) => const LoginScreen(),
      data: (session) {
        if (session == null) return const LoginScreen();
        if (lockAsync.value?.locked == true) return const BiometricLockScreen();
        if (session.needsAccountSelection) {
          return AccountPickerScreen(accounts: session.accounts);
        }
        return session.mode == AuthMode.agent ? const AgentHomeShell() : const ClientHomeShell();
      },
    );
  }
}
