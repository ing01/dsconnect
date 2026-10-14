import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../data/client_repository.dart';
import '../data/notification_dismiss_store.dart';
import '../models/chat_message.dart';
import '../models/client_notification.dart';
import '../models/client_ticket.dart';
import '../models/client_ticket_detail.dart';
import '../models/company.dart';
import '../models/ticket_category.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider));
});

class ClientTicketsState {
  const ClientTicketsState({
    this.tickets = const [],
    this.companies = const [],
    this.companyId,
    this.query = '',
  });

  final List<ClientTicket> tickets;
  final List<Company> companies;
  final int? companyId;
  final String query;

  ClientTicketsState copyWith({
    List<ClientTicket>? tickets,
    List<Company>? companies,
    int? companyId,
    bool clearCompany = false,
    String? query,
  }) =>
      ClientTicketsState(
        tickets: tickets ?? this.tickets,
        companies: companies ?? this.companies,
        companyId: clearCompany ? null : (companyId ?? this.companyId),
        query: query ?? this.query,
      );
}

// "Meus chamados" - lista unica, todas as Mesas juntas (ver o comentario no
// controller do servidor: o board deixou de recortar por Mesa do lado do
// cliente). Puxar pra atualizar chama `refresh()`.
class ClientTicketsNotifier extends AsyncNotifier<ClientTicketsState> {
  @override
  Future<ClientTicketsState> build() async {
    final result = await ref.read(clientRepositoryProvider).fetchTickets();
    return ClientTicketsState(tickets: result.tickets, companies: result.companies);
  }

  Future<void> refresh() async {
    final current = state.value ?? const ClientTicketsState();
    final result = await ref.read(clientRepositoryProvider).fetchTickets(
          companyId: current.companyId,
          query: current.query,
        );
    state = AsyncData(current.copyWith(tickets: result.tickets, companies: result.companies));
  }

  Future<void> filterByCompany(int? companyId) async {
    final current = state.value ?? const ClientTicketsState();
    state = AsyncData(current.copyWith(companyId: companyId, clearCompany: companyId == null));
    await refresh();
  }

  Future<void> search(String query) async {
    final current = state.value ?? const ClientTicketsState();
    if (current.query == query) return;
    state = AsyncData(current.copyWith(query: query));
    await refresh();
  }
}

final clientTicketsProvider = AsyncNotifierProvider<ClientTicketsNotifier, ClientTicketsState>(
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
  Future<void> reply(String body, {List<XFile> attachments = const []}) async {
    await ref.read(clientRepositoryProvider).replyToTicket(ticketId, body, attachments: attachments);
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

final _notificationDismissStoreProvider = Provider<NotificationDismissStore>((ref) => NotificationDismissStore());

// Ids de notificacao ja abertas pelo cliente - some da lista ao clicar, ainda
// que o servidor nao tenha coluna de lido/nao-lido (ver NotificationDismissStore).
class DismissedNotificationsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ref.read(_notificationDismissStoreProvider).read();

  Future<void> dismiss(String id) async {
    final current = state.value ?? const {};
    if (current.contains(id)) return;

    state = AsyncData({...current, id});
    await ref.read(_notificationDismissStoreProvider).dismiss(id);
  }

  // Pra sumir a notificacao tambem quando a conversa e' aberta por outro
  // caminho (ex.: o chamado pela lista "Meus chamados", ou o Chat direto
  // pela aba) - nao so quando se clica na propria notificacao.
  Future<void> dismissForTicket(int ticketId) async {
    final all = ref.read(clientNotificationsProvider).value ?? const [];
    for (final item in all) {
      if (item.ticketId == ticketId) await dismiss(item.id);
    }
  }

  Future<void> dismissChatNotifications() async {
    final all = ref.read(clientNotificationsProvider).value ?? const [];
    for (final item in all) {
      if (item.type != 'ticket') await dismiss(item.id);
    }
  }
}

final dismissedNotificationsProvider = AsyncNotifierProvider<DismissedNotificationsNotifier, Set<String>>(
  DismissedNotificationsNotifier.new,
);

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
