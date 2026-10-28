import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/biometric_lock.dart';
import '../../core/auth/biometric_menu_item.dart';
import '../../core/push/push_notification_service.dart';
import '../../core/realtime/action_cable_client.dart';
import 'client_account_screen.dart';
import 'client_chat_screen.dart';
import 'client_notifications_screen.dart';
import 'client_ticket_detail_screen.dart';
import 'models/client_notification.dart';
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
  ActionCableClient? _cable;
  // Ids ja vistos na lista de notificacoes. A primeira lista so popula; dai em
  // diante, o que aparece e' novidade e merece um aviso dentro do app.
  final _knownNotificationIds = <String>{};
  bool _notificationsLoadedOnce = false;
  // Guardado aqui porque `ref` nao serve dentro do `dispose`.
  late final PushNotificationService _push;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Rede de seguranca da aba Notificacoes: o push que chega com o app em
    // segundo plano nao passa por aqui (so o sistema o mostra), entao a lista
    // so se atualizava ao puxar a tela. Buscar de tempos em tempos, e ao voltar
    // do segundo plano, mantem a aba em dia sem depender de nada. O relogio so
    // corre com o app a vista (ver `didChangeAppLifecycleState`).
    _startNotificationsTimer();
    _connectRealtime();
    _push = ref.read(pushNotificationServiceProvider);
    // Chegou push com o app aberto - recarrega a lista pra bolinha do Chat
    // (e a aba Notificações) refletirem na hora, sem esperar o proximo
    // reload manual. Quem decide se a bolinha acende e' o `ref.listen` do
    // `build`, que vale para qualquer caminho que traga dados novos (push,
    // WebSocket do chat, relogio, volta do segundo plano).
    _pushSubscription = _push.onMessageReceived.listen((_) => _refreshNotifications());
  }

  // O numero no icone diz QUANTAS coisas novas esperam; so a bolinha nao diz
  // se e' uma ou dez. O Chat conta as respostas da equipe ainda nao vistas, e
  // Notificacoes conta tudo o que ainda nao foi aberto.
  Widget _tabIcon(int index, {required int unreadChat, required int unreadTotal}) {
    final count = index == _chatTabIndex
        ? unreadChat
        : index == _notificationsTabIndex
            ? unreadTotal
            : 0;
    final icon = Icon(_tabs[index].icon);
    if (count == 0) return icon;

    return Badge(label: Text(count > 9 ? '9+' : '$count'), child: icon);
  }

  // Chegou algo novo com o app aberto: alem do aviso do sistema, uma faixa
  // dentro do app diz QUEM respondeu, ONDE e O QUE - e um toque leva la. Sem
  // isto, quem esta em outra aba so ficava sabendo olhando o icone.
  void _announceNewNotifications(List<ClientNotification> items) {
    final fresh = items.where((item) => !_knownNotificationIds.contains(item.id)).toList();
    final firstLoad = !_notificationsLoadedOnce;
    _knownNotificationIds.addAll(items.map((item) => item.id));
    _notificationsLoadedOnce = true;

    if (firstLoad || fresh.isEmpty || !mounted) return;

    // Dentro do Chat a conversa ja esta a vista.
    final visible = fresh.where((item) => !item.isChat || _currentIndex != _chatTabIndex).toList();
    if (visible.isEmpty) return;

    visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = visible.first;
    final extra = visible.length - 1;
    final isTicket = latest.isTicketRelated;
    final who = latest.authorName?.trim().isNotEmpty == true ? latest.authorName!.trim() : 'A equipe';
    final where = isTicket ? 'no chamado #${latest.ticketDisplayId}' : 'no chat';
    final preview = latest.preview.isEmpty ? '' : ': ${latest.preview}';
    final text = latest.isTicketMoved
        ? 'Chamado #${latest.ticketDisplayId} encaminhado$preview'
        : '$who respondeu $where$preview';

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text(
          '$text${extra > 0 ? '  (+$extra)' : ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () {
            if (isTicket && latest.ticketId != null) {
              ref.read(dismissedNotificationsProvider.notifier).dismiss(latest.id);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: latest.ticketId!)),
              );
            } else {
              _selectTab(_chatTabIndex);
            }
          },
        ),
      ),
    );
  }

  void _refreshNotifications() {
    if (mounted) ref.invalidate(clientNotificationsProvider);
  }

  // Tempo real: o servidor avisa (`ClientNotificationsChannel`) assim que a
  // equipe responde ou encaminha um chamado, e a lista e' buscada na hora. O
  // relogio abaixo fica como rede de seguranca, para o que o socket perder.
  void _connectRealtime() {
    final token = ref.read(sessionProvider).value?.apiAccessToken;
    if (token == null) return;

    _cable = ActionCableClient()..subscribe({'channel': 'ClientNotificationsChannel', 'api_access_token': token});
    _cable!.events.listen((event) {
      final name = event['event'];
      if (name == 'client.notification' || name == ActionCableClient.restoredEvent) _refreshNotifications();
    });
  }

  // A cada 10s: curto o bastante pra novidade aparecer quase na hora, e a
  // chamada e leve (uma lista de ate 50 itens).
  void _startNotificationsTimer() {
    _notificationsTimer?.cancel();
    _notificationsTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshNotifications());
  }

  // Voltar do segundo plano - inclusive ao tocar numa notificacao do sistema -
  // e quando mais avisos novos existem. Em segundo plano o relogio para: ali
  // quem avisa e' o push, e consultar o servidor so gastaria bateria e dados.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // O sistema pode ter derrubado o socket em segundo plano sem avisar.
      _cable?.reconnect();
      _refreshNotifications();
      _startNotificationsTimer();
    } else if (state == AppLifecycleState.paused) {
      _notificationsTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsTimer?.cancel();
    _cable?.dispose();
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

    // A primeira lista que o app ve so popula o que ja existia: nao vira aviso.
    // Feito aqui tambem (e nao so no listen) porque a lista pode ja estar
    // carregada quando a tela monta, e entao o listen nunca dispara por ela.
    final loadedItems = notificationsAsync.value;
    if (!_notificationsLoadedOnce && loadedItems != null) {
      _knownNotificationIds.addAll(loadedItems.map((item) => item.id));
      _notificationsLoadedOnce = true;
    }

    // Dentro do Chat a mensagem ja esta na tela: a bolinha de "mensagem nova"
    // nao deve acender (so a do ticket, que nao esta a vista). Vale para toda
    // lista nova que chegar com o Chat aberto, nao so para a do push - antes
    // so o push dispensava, e uma mensagem trazida por outro caminho acendia a
    // bolinha em cima do proprio Chat.
    ref.listen(clientNotificationsProvider, (_, next) {
      final items = next.value;
      if (items == null) return;

      _announceNewNotifications(items);

      if (_currentIndex == _chatTabIndex) {
        ref.read(dismissedNotificationsProvider.notifier).dismissChatNotifications();
      }
    });
    final dismissed = ref.watch(dismissedNotificationsProvider).value ?? const {};
    final unread = (notificationsAsync.value ?? const <ClientNotification>[])
        .where((item) => !dismissed.contains(item.id))
        .toList();
    // Dentro do Chat as mensagens ja estao na tela - nao contam como pendentes.
    final unreadChat =
        _currentIndex == _chatTabIndex ? 0 : unread.where((item) => item.isChat).length;
    final unreadTotal = unread.length;

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
              icon: _tabIcon(i, unreadChat: unreadChat, unreadTotal: unreadTotal),
              label: _tabs[i].title,
            ),
        ],
      ),
    );
  }
}
