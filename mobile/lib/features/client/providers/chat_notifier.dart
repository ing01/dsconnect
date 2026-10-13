import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/action_cable_client.dart';
import 'client_providers.dart';

// O Chat do Portal com a equipe, com tempo real: ao abrir, busca o
// historico e assina o `RoomChannel` pelo `pubsub_token` da conversa (o
// MESMO mecanismo do Widget). Quando chega um 'message.created' daquele
// canal, recarrega o historico pela REST em vez de tentar remontar a
// mensagem a partir do payload do evento - mais simples e sempre bate com
// o que a tela de detalhe/comunicacao ja mostra.
//
// `autoDispose`: a conexao WebSocket fecha sozinha quando a tela de chat
// sai da arvore (ninguem mais observando este provider).
class ClientChatNotifier extends AsyncNotifier<ChatState> {
  ActionCableClient? _cable;

  @override
  Future<ChatState> build() async {
    ref.onDispose(() => _cable?.dispose());

    final session = await ref.read(clientRepositoryProvider).fetchChat();
    _connectRealtime(session.pubsubToken);
    return ChatState(session: session);
  }

  void _connectRealtime(String pubsubToken) {
    _cable?.dispose();
    _cable = ActionCableClient()..connect(pubsubToken: pubsubToken);
    _cable!.events.listen((event) {
      if (event['event'] == 'message.created') refresh();
    });
  }

  Future<void> refresh() async {
    final session = await ref.read(clientRepositoryProvider).fetchChat();
    // A sessao de chat pode trocar de conversa (sessao anterior resolvida
    // vira uma nova) - se o pubsub_token mudou, reconecta no canal certo.
    if (state.value?.session?.pubsubToken != session.pubsubToken) {
      _connectRealtime(session.pubsubToken);
    }
    state = AsyncData(ChatState(session: session));
  }

  Future<void> send(String content) async {
    final current = state.value ?? const ChatState();
    state = AsyncData(current.copyWith(isSending: true, clearError: true));
    try {
      await ref.read(clientRepositoryProvider).sendChatMessage(content);
      await refresh();
    } catch (_) {
      state = AsyncData(current.copyWith(isSending: false, error: 'Não foi possível enviar a mensagem.'));
    }
  }
}

final clientChatProvider = AsyncNotifierProvider.autoDispose<ClientChatNotifier, ChatState>(
  ClientChatNotifier.new,
);
