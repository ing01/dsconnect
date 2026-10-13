import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';

// Placeholder da Fase 1 - meus chamados, abertura por IA e chat chegam na
// Fase 3 (ver o plano do app).
class ClientHomeShell extends ConsumerWidget {
  const ClientHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DSConnect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Login de cliente funcionando.\nA lista de chamados chega na próxima etapa.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
