import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'client_chat_screen.dart';
import 'client_notifications_screen.dart';
import 'client_tickets_list_screen.dart';
import 'providers/client_providers.dart';

enum _AppBarAction { logout, deleteAccount }

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
  // Abas já visitadas pelo usuário nesta sessão. O Chat só é montado (e sua
  // conexão WebSocket + chamada ao servidor só são abertas) quando o usuário
  // toca na aba pela primeira vez — evita disparar "Nova Mensagem" no painel
  // do colaborador só porque o cliente logou.
  final _visited = <int>{0};
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

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    String? errorMsg;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Excluir minha conta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta ação é permanente e não pode ser desfeita. Seus dados pessoais serão removidos e você não conseguirá mais fazer login.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Confirme sua senha',
                  hintText: 'Digite sua senha',
                  errorText: errorMsg,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final password = passwordController.text;
                if (password.isEmpty) return;
                try {
                  await ref
                      .read(clientRepositoryProvider)
                      .deleteAccount(password);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  ref.read(sessionProvider.notifier).logout();
                } catch (e) {
                  setDialogState(() {
                    errorMsg = 'Senha incorreta. Verifique e tente novamente.';
                  });
                }
              },
              child: const Text('Excluir minha conta'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
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
          PopupMenuButton<_AppBarAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Mais opções',
            onSelected: (action) {
              switch (action) {
                case _AppBarAction.logout:
                  ref.read(sessionProvider.notifier).logout();
                case _AppBarAction.deleteAccount:
                  _showDeleteAccountDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _AppBarAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _AppBarAction.deleteAccount,
                child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: Text('Excluir minha conta', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _visited.contains(i) ? _tabs[i].screen : const SizedBox.shrink(),
        ],
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
