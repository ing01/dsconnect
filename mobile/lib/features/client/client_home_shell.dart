import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'client_chat_screen.dart';
import 'client_notifications_screen.dart';
import 'client_tickets_list_screen.dart';
import 'providers/client_providers.dart';

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
const _chatTabIndex = 1;

class _ClientHomeShellState extends ConsumerState<ClientHomeShell> {
  int _currentIndex = 0;
  StreamSubscription<void>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    // Chegou push com o app aberto - recarrega a lista pra bolinha do Chat
    // (e a aba Notificações) refletirem na hora, sem esperar o proximo
    // reload manual.
    _pushSubscription = ref.read(pushNotificationServiceProvider).onMessageReceived.listen((_) {
      ref.invalidate(clientNotificationsProvider);
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    // Entrar na aba do Chat conta como "ver" as mensagens novas - some a
    // bolinha vermelha do icone.
    if (index == _chatTabIndex) {
      ref.read(dismissedNotificationsProvider.notifier).dismissChatNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(clientNotificationsProvider);
    final dismissed = ref.watch(dismissedNotificationsProvider).value ?? const {};
    final hasUnreadChat = (notificationsAsync.value ?? const [])
        .any((item) => item.type != 'ticket' && !dismissed.contains(item.id));

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
        onDestinationSelected: _selectTab,
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: i == _chatTabIndex
                  ? Badge(isLabelVisible: hasUnreadChat, child: Icon(_tabs[i].icon))
                  : Icon(_tabs[i].icon),
              label: _tabs[i].title,
            ),
        ],
      ),
    );
  }
}
