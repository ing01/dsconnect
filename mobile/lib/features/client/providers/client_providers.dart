import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../data/client_repository.dart';
import '../models/chat_message.dart';
import '../models/client_notification.dart';
import '../models/client_ticket.dart';
import '../models/client_ticket_detail.dart';
import '../models/ticket_category.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider));
});

// "Meus chamados" - lista unica, todas as Mesas juntas (ver o comentario no
// controller do servidor: o board deixou de recortar por Mesa do lado do
// cliente). Puxar pra atualizar chama `refresh()`.
class ClientTicketsNotifier extends AsyncNotifier<List<ClientTicket>> {
  @override
  Future<List<ClientTicket>> build() => ref.read(clientRepositoryProvider).fetchTickets();

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(clientRepositoryProvider).fetchTickets());
  }
}

final clientTicketsProvider = AsyncNotifierProvider<ClientTicketsNotifier, List<ClientTicket>>(
  ClientTicketsNotifier.new,
);

class ClientTicketDetailNotifier extends AsyncNotifier<ClientTicketDetail> {
  ClientTicketDetailNotifier(this.ticketId);

  final int ticketId;

  @override
  Future<ClientTicketDetail> build() => ref.read(clientRepositoryProvider).fetchTicketDetail(ticketId);

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(clientRepositoryProvider).fetchTicketDetail(ticketId));
  }

  // Responde e recarrega o detalhe (pra trazer a mensagem nova junto, com
  // o mesmo formato/ordenacao que o resto da conversa) - mais simples e mais
  // confiavel do que tentar inserir a mensagem local "na mao".
  Future<void> reply(String body) async {
    await ref.read(clientRepositoryProvider).replyToTicket(ticketId, body);
    await refresh();
  }
}

final clientTicketDetailProvider = AsyncNotifierProvider.autoDispose.family<
    ClientTicketDetailNotifier, ClientTicketDetail, int>(ClientTicketDetailNotifier.new);

final ticketCategoriesProvider = FutureProvider.autoDispose<List<TicketCategory>>((ref) {
  return ref.watch(clientRepositoryProvider).fetchCategories();
});

final aiDraftEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(clientRepositoryProvider).isAiDraftEnabled();
});

final clientNotificationsProvider = FutureProvider.autoDispose<List<ClientNotification>>((ref) {
  return ref.watch(clientRepositoryProvider).fetchNotifications();
});

// Estado do Chat do Portal - ver `ClientChatNotifier` (providers/chat_notifier.dart)
// pela parte de tempo real.
class ChatState {
  const ChatState({this.session, this.isSending = false, this.error});

  final ChatSession? session;
  final bool isSending;
  final String? error;

  ChatState copyWith({ChatSession? session, bool? isSending, String? error, bool clearError = false}) => ChatState(
        session: session ?? this.session,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : (error ?? this.error),
      );
}
