import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../tickets/ticket_list_screen.dart';

// Fase 2 - "Meus tickets". Notificações e tempo real ainda faltam (ver o
// plano do app).
class AgentHomeShell extends ConsumerWidget {
  const AgentHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: const TicketListScreen(),
    );
  }
}
