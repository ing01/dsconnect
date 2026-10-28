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
// desconecta quando fecha. Se a conexao cair (app em segundo plano, troca de
// rede, servidor reiniciando) ela religa sozinha, com espera crescente entre
// as tentativas, e avisa com o evento `connection.restored` para quem escuta
// buscar o que perdeu enquanto estava fora.
class ActionCableClient {
  ActionCableClient();

  static const restoredEvent = 'connection.restored';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  String? _identifier;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _closed = false;
  bool _everConnected = false;

  // Cada evento recebido no canal ('message.created', 'presence.update' etc,
  // ver action_cable_listener.rb no servidor) - com `event`/`data` como o
  // servidor manda.
  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  void connect({required String pubsubToken, int? userId, int? accountId}) {
    final params = <String, dynamic>{'channel': 'RoomChannel', 'pubsub_token': pubsubToken};
    if (userId != null) params['user_id'] = userId;
    if (accountId != null) params['account_id'] = accountId;
    _identifier = jsonEncode(params);

    _open();
  }

  // Forca uma conexao nova agora - usado ao voltar do segundo plano, quando o
  // sistema pode ter matado o socket sem avisar (e sem `onDone`).
  void reconnect() {
    if (_closed || _identifier == null) return;
    _retryTimer?.cancel();
    _attempt = 0;
    _open();
  }

  void _open() {
    _subscription?.cancel();
    _channel?.sink.close();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl()));
    } catch (_) {
      _scheduleRetry();
      return;
    }

    _subscription = _channel!.stream.listen(
      _handleFrame,
      onError: (_) => _scheduleRetry(),
      onDone: _scheduleRetry,
      cancelOnError: true,
    );
  }

  void _scheduleRetry() {
    if (_closed) return;
    _retryTimer?.cancel();
    // 2s, 4s, 8s... ate 30s: rapido o bastante pra voltar logo, sem martelar o
    // servidor quando ele esta fora do ar.
    final seconds = (2 << _attempt).clamp(2, 30);
    if (_attempt < 4) _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), _open);
  }

  void _handleFrame(dynamic raw) {
    if (_closed) return;
    final frame = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = frame['type'] as String?;

    if (type == 'welcome') {
      _send({'command': 'subscribe', 'identifier': _identifier});
      return;
    }
    if (type == 'confirm_subscription') {
      _attempt = 0;
      // Na primeira vez o chamador acabou de buscar o historico; nas seguintes
      // ficou um intervalo sem escuta, e as mensagens dele precisam ser buscadas.
      if (_everConnected) _eventsController.add({'event': restoredEvent});
      _everConnected = true;
      return;
    }
    if (type == 'ping' || type == 'reject_subscription') return;

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
    _closed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventsController.close();
  }
}
