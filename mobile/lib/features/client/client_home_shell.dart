import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'client_chat_screen.dart';
import 'client_notifications_screen.dart';
import 'client_tickets_list_screen.dart';

// Fase 3 - modo cliente: chamados, chat com a equipe e notificações. O
// colaborador fica em segundo plano por enquanto (pedido da Ingrid).
class ClientHomeShell extends ConsumerStatefulWidget {
  const ClientHomeShell({super.key});

  @override
  ConsumerState<ClientHomeShell> createState() => _ClientHomeShellState();
}

const _tabs = [
  (title: 'Meus chamados', icon: Icons.confirmation_number_outlined, screen: ClientTicketsListScreen()),
  (title: 'Chat', icon: Icons.chat_bubble_outline, screen: ClientChatScreen()),
  (title: 'Notificações', icon: Icons.notifications_none, screen: ClientNotificationsScreen()),
];

class _ClientHomeShellState extends ConsumerState<ClientHomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [for (final tab in _tabs) tab.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          for (final tab in _tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.title),
        ],
      ),
    );
  }
}
