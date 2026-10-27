import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/biometric_lock.dart';
import '../../core/auth/biometric_menu_item.dart';
import '../tickets/ticket_list_screen.dart';

enum _AppBarAction { biometric, logout }

// Fase 2 - "Meus tickets". Notificações e tempo real ainda faltam (ver o
// plano do app).
class AgentHomeShell extends ConsumerWidget {
  const AgentHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricEnabled = ref.watch(biometricLockProvider).value?.enabled ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus tickets'),
        actions: [
          PopupMenuButton<_AppBarAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Mais opções',
            onSelected: (action) {
              switch (action) {
                case _AppBarAction.biometric:
                  ref.read(biometricLockProvider.notifier).disable();
                case _AppBarAction.logout:
                  ref.read(sessionProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              if (biometricEnabled)
                const PopupMenuItem(value: _AppBarAction.biometric, child: BiometricMenuTile()),
              const PopupMenuItem(
                value: _AppBarAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: const TicketListScreen(),
    );
  }
}
