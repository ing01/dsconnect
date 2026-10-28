import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/biometric_lock.dart';
import '../../core/auth/biometric_menu_item.dart';
import '../../core/push/push_notification_service.dart';
import 'client_account_screen.dart';
import 'client_chat_screen.dart';
import 'client_notifications_screen.dart';
import 'client_tickets_list_screen.dart';
import 'providers/chat_notifier.dart';
import 'providers/client_providers.dart';

enum _AppBarAction { biometric, account, logout }

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
const _notificationsTabIndex = 2;

class _ClientHomeShellState extends ConsumerState<ClientHomeShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  // Abas já visitadas pelo usuário nesta sessão. O Chat só é montado (e sua
  // conexão WebSocket + chamada ao servidor só são abertas) quando o usuário
  // toca na aba pela primeira vez — evita disparar "Nova Mensagem" no painel
  // do colaborador só porque o cliente logou.
  final _visited = <int>{0};
  StreamSubscription<void>? _pushSubscription;
  Timer? _notificationsTimer;
  // Guardado aqui porque `ref` nao serve dentro do `dispose`.
  late final PushNotificationService _push;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Rede de seguranca da aba Notificacoes: o push que chega com o app em
    // segundo plano nao passa por aqui (so o sistema o mostra), entao a lista
    // so se atualizava ao puxar a tela. Buscar de tempos em tempos, e ao voltar
    // do segundo plano, mantem a aba em dia sem depender de nada.
    _notificationsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshNotifications());
    _push = ref.read(pushNotificationServiceProvider);
    // Chegou push com o app aberto - recarrega a lista pra bolinha do Chat
    // (e a aba Notificações) refletirem na hora, sem esperar o proximo
    // reload manual. Quem decide se a bolinha acende e' o `ref.listen` do
    // `build`, que vale para qualquer caminho que traga dados novos (push,
    // WebSocket do chat, relogio, volta do segundo plano).
    _pushSubscription = _push.onMessageReceived.listen((_) => _refreshNotifications());
  }

  void _refreshNotifications() {
    if (mounted) ref.invalidate(clientNotificationsProvider);
  }

  // Voltar do segundo plano - inclusive ao tocar numa notificacao do sistema -
  // e quando mais avisos novos existem.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsTimer?.cancel();
    _pushSubscription?.cancel();
    // Sair desta tela (ex.: logout) nao pode deixar o aviso de conversa
    // suprimido para o proximo login.
    _push.chatTabOpen = false;
    super.dispose();
  }

  void _selectTab(int index) {
    // Com a aba do Chat aberta, o push de conversa nao e' mostrado (ver
    // `PushNotificationService.chatTabOpen`).
    _push.chatTabOpen = index == _chatTabIndex;
    final chatAlreadyOpened = _visited.contains(_chatTabIndex);
    // Entrar na aba Notificacoes sempre mostra a lista atual do servidor.
    if (index == _notificationsTabIndex) _refreshNotifications();
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
    // Entrar na aba do Chat conta como "ver" as mensagens novas - some a
    // bolinha vermelha do icone.
    if (index == _chatTabIndex) {
      ref.read(dismissedNotificationsProvider.notifier).dismissChatNotifications();
      // Voltar para a aba traz o que chegou enquanto estava em outra. Na primeira
      // visita a tela acabou de montar e ja busca o historico sozinha.
      if (chatAlreadyOpened) ref.read(clientChatProvider.notifier).resync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(biometricLockProvider).value?.enabled ?? false;
    final notificationsAsync = ref.watch(clientNotificationsProvider);

    // Dentro do Chat a mensagem ja esta na tela: a bolinha de "mensagem nova"
    // nao deve acender (so a do ticket, que nao esta a vista). Vale para toda
    // lista nova que chegar com o Chat aberto, nao so para a do push - antes
    // so o push dispensava, e uma mensagem trazida por outro caminho acendia a
    // bolinha em cima do proprio Chat.
    ref.listen(clientNotificationsProvider, (_, next) {
      if (_currentIndex == _chatTabIndex && next.hasValue) {
        ref.read(dismissedNotificationsProvider.notifier).dismissChatNotifications();
      }
    });
    final dismissed = ref.watch(dismissedNotificationsProvider).value ?? const {};
    final hasUnreadChat = (notificationsAsync.value ?? const [])
        .any((item) => item.type != 'ticket' && !dismissed.contains(item.id)) &&
        _currentIndex != _chatTabIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].title),
        actions: [
          PopupMenuButton<_AppBarAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Mais opções',
            onSelected: (action) {
              switch (action) {
                case _AppBarAction.biometric:
                  ref.read(biometricLockProvider.notifier).disable();
                case _AppBarAction.account:
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClientAccountScreen()));
                case _AppBarAction.logout:
                  ref.read(sessionProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              if (biometricEnabled)
                const PopupMenuItem(value: _AppBarAction.biometric, child: BiometricMenuTile()),
              const PopupMenuItem(
                value: _AppBarAction.account,
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Minha conta'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
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
