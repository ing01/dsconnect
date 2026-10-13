import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_mode.dart';
import 'core/auth/auth_providers.dart';
import 'features/agent/agent_home_shell.dart';
import 'features/auth/account_picker_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/client/client_home_shell.dart';

class DuedeskApp extends StatelessWidget {
  const DuedeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2781F6), useMaterial3: true),
      home: const _RootGate(),
    );
  }
}

// Decide qual tela mostrar conforme o estado da sessão - sem rotas
// nomeadas por enquanto, o app ainda é pequeno o bastante pra isso bastar.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Sessão salva veio corrompida/expirada de um jeito que a leitura
      // falhou - trata como deslogado em vez de travar o app numa tela de
      // erro sem saída.
      error: (_, _) => const LoginScreen(),
      data: (session) {
        if (session == null) return const LoginScreen();
        if (session.needsAccountSelection) {
          return AccountPickerScreen(accounts: session.accounts);
        }
        return session.mode == AuthMode.agent ? const AgentHomeShell() : const ClientHomeShell();
      },
    );
  }
}
