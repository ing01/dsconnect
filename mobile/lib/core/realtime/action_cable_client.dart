import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';

// Cliente ActionCable minimo, escrito a mao - o protocolo e' so JSON com
// command/identifier/data (ver o `RoomChannel` do servidor, o MESMO canal
// que o painel web e o Widget ja usam). Os pacotes prontos de ActionCable
// pro Dart estao desatualizados/mal mantidos, entao nao vale a dependencia
// so pra isso.
//
// Um cliente por tela (ver `ClientChatScreen`) - conecta quando a tela abre,
// desconecta quando fecha. Sem reconexao automatica por enquanto: se cair,
// a proxima visita a tela reconecta do zero.
class ActionCableClient {
  ActionCableClient();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  String? _identifier;

  // Cada evento recebido no canal ('message.created', 'presence.update' etc,
  // ver action_cable_listener.rb no servidor) - com `event`/`data` como o
  // servidor manda.
  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  void connect({required String pubsubToken, int? userId, int? accountId}) {
    final wsUrl = _wsUrl();
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    final params = <String, dynamic>{'channel': 'RoomChannel', 'pubsub_token': pubsubToken};
    if (userId != null) params['user_id'] = userId;
    if (accountId != null) params['account_id'] = accountId;
    _identifier = jsonEncode(params);

    _subscription = _channel!.stream.listen(_handleFrame, onError: (_) {}, onDone: () {});
  }

  void _handleFrame(dynamic raw) {
    final frame = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = frame['type'] as String?;

    if (type == 'welcome') {
      _send({'command': 'subscribe', 'identifier': _identifier});
      return;
    }
    if (type == 'ping' || type == 'confirm_subscription' || type == 'reject_subscription') return;

    final message = frame['message'];
    if (message is Map<String, dynamic>) _eventsController.add(message);
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  String _wsUrl() {
    final uri = Uri.parse(AppConfig.baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.authority}/cable';
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _eventsController.close();
  }
}
