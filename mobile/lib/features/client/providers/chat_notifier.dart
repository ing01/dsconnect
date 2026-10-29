import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/realtime/action_cable_client.dart';
import '../models/chat_message.dart';
import '../chat_blocked.dart';
import 'client_providers.dart';

// O Chat do Portal com a equipe, com tempo real: ao abrir, busca o
// historico e assina o `RoomChannel` pelo `pubsub_token` da conversa (o
// MESMO mecanismo do Widget). Quando chega um 'message.created' daquele
// canal, recarrega o historico pela REST em vez de tentar remontar a
// mensagem a partir do payload do evento - mais simples e sempre bate com
// o que a tela de detalhe/comunicacao ja mostra.
//
// O WebSocket sozinho nao basta: em segundo plano o sistema o derruba sem
// avisar, e a mensagem que chega nesse intervalo nunca e entregue por ele.
// Por isso o historico tambem e buscado quando o push chega com o app aberto,
// quando o socket volta a conectar, quando o app volta do segundo plano e,
// como rede de seguranca, de tempos em tempos (ver `ClientChatScreen`).
//
// `autoDispose`: a conexao WebSocket fecha sozinha quando a tela de chat
// sai da arvore (ninguem mais observando este provider).
class ClientChatNotifier extends AsyncNotifier<ChatState> {
  ActionCableClient? _cable;
  StreamSubscription<void>? _pushSubscription;

  @override
  Future<ChatState> build() async {
    ref.onDispose(() {
      _pushSubscription?.cancel();
      _cable?.dispose();
    });

    // Chegou push com o app aberto: a mensagem nova ja esta no servidor, mesmo
    // que o socket nao a tenha entregue.
    _pushSubscription = ref.read(pushNotificationServiceProvider).onMessageReceived.listen((_) => refresh());

    final session = await ref.read(clientRepositoryProvider).fetchChat();
    // Sem conversa ainda (primeiro acesso, antes de qualquer mensagem):
    // pubsubToken e' null. Nao ha canal para assinar agora; _connectRealtime
    // sera' chamado em refresh(), que roda apos o primeiro envio.
    if (session.pubsubToken != null) _connectRealtime(session.pubsubToken!);
    return ChatState(session: session);
  }

  void _connectRealtime(String pubsubToken) {
    _cable?.dispose();
    _cable = ActionCableClient()..connect(pubsubToken: pubsubToken);
    _cable!.events.listen((event) {
      final name = event['event'];
      if (name == 'message.created' || name == ActionCableClient.restoredEvent) {
        refresh();
        // A bolinha do Chat nao pode depender so do push: se ele atrasar ou nao
        // vier, a mensagem que chegou por aqui ainda acende a bolinha.
        ref.invalidate(clientNotificationsProvider);
      }
    });
  }

  // Ao voltar do segundo plano o socket pode estar morto sem ninguem saber:
  // religa e busca o que chegou enquanto o app estava fora.
  Future<void> resync() async {
    _cable?.reconnect();
    await refresh();
  }

  Future<void> refresh() async {
    final ChatSession session;
    try {
      session = await ref.read(clientRepositoryProvider).fetchChat();
    } catch (_) {
      // Sem rede agora: mantem o que ja esta na tela. A proxima tentativa
      // (push, socket religado, volta do app ou o relogio) busca de novo.
      final current = state.value;
      if (current != null && current.isSending) state = AsyncData(current.copyWith(isSending: false));
      return;
    }

    // A sessao de chat pode trocar de conversa (sessao anterior resolvida
    // vira uma nova, ou foi criada agora pelo primeiro envio) - se o
    // pubsub_token mudou (inclusive de null para um token real), reconecta.
    if (session.pubsubToken != null &&
        state.value?.session?.pubsubToken != session.pubsubToken) {
      _connectRealtime(session.pubsubToken!);
    }
    state = AsyncData(ChatState(session: session));
  }

  Future<void> send(
    String content, {
    List<XFile> attachments = const [],
    bool isVoiceMessage = false,
  }) async {
    final current = state.value ?? const ChatState();
    state = AsyncData(current.copyWith(isSending: true, clearError: true));
    try {
      await ref.read(clientRepositoryProvider).sendChatMessage(
            content,
            attachments: attachments,
            isVoiceMessage: isVoiceMessage,
          );
      await refresh();
    } catch (error) {
      state = AsyncData(current.copyWith(
        isSending: false,
        error: chatBlockedMessage(error) ?? 'Não foi possível enviar a mensagem.',
      ));
    }
  }
}

final clientChatProvider = AsyncNotifierProvider.autoDispose<ClientChatNotifier, ChatState>(
  ClientChatNotifier.new,
);
