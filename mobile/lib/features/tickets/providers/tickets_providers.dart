import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../data/tickets_repository.dart';
import '../models/team.dart';
import '../models/ticket_summary.dart';

final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) {
  return TicketsRepository(ref.watch(apiClientProvider));
});

// A conta do colaborador logado - toda chamada de ticket/time precisa dela
// na URL. `null` so' acontece num estado transitorio (sessao ainda
// carregando ou ainda sem conta escolhida), e quem usa isto ja trata esse
// caso (ver `TicketListScreen`).
final currentAccountIdProvider = Provider<int?>((ref) {
  final session = ref.watch(sessionProvider).value;
  return session?.selectedAccountId;
});

final teamsProvider = FutureProvider<List<Team>>((ref) async {
  final accountId = ref.watch(currentAccountIdProvider);
  if (accountId == null) return const [];
  return ref.watch(ticketsRepositoryProvider).fetchTeams(accountId);
});

// `null` = "todas as Mesas que participo" (sem filtro).
class SelectedTeamIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? teamId) => state = teamId;
}

final selectedTeamIdProvider = NotifierProvider<SelectedTeamIdNotifier, int?>(SelectedTeamIdNotifier.new);

class TicketsState {
  const TicketsState({
    this.tickets = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  final List<TicketSummary> tickets;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  TicketsState copyWith({
    List<TicketSummary>? tickets,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? page,
    bool? hasMore,
  }) =>
      TicketsState(
        tickets: tickets ?? this.tickets,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
      );
}

// "Meus tickets", paginado com "carregar mais" (sem rolagem infinita
// automatica por enquanto - mais simples e mais previsivel numa lista que
// pode ter dezenas de paginas).
class TicketsNotifier extends Notifier<TicketsState> {
  @override
  TicketsState build() {
    // Recarrega do zero sempre que a Mesa filtrada mudar.
    ref.listen(selectedTeamIdProvider, (previous, next) {
      if (previous != next) refresh();
    });
    Future.microtask(refresh);
    return const TicketsState(isLoading: true);
  }

  Future<void> refresh() async {
    final accountId = ref.read(currentAccountIdProvider);
    if (accountId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref.read(ticketsRepositoryProvider).fetchMine(
            accountId: accountId,
            teamId: ref.read(selectedTeamIdProvider),
            page: 1,
          );
      state = TicketsState(
        tickets: page.tickets,
        page: page.currentPage,
        hasMore: page.tickets.length < page.totalCount,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Não foi possível carregar os tickets.');
    }
  }

  Future<void> loadMore() async {
    final accountId = ref.read(currentAccountIdProvider);
    if (accountId == null || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final page = await ref.read(ticketsRepositoryProvider).fetchMine(
            accountId: accountId,
            teamId: ref.read(selectedTeamIdProvider),
            page: nextPage,
          );
      state = state.copyWith(
        tickets: [...state.tickets, ...page.tickets],
        isLoadingMore: false,
        page: page.currentPage,
        hasMore: state.tickets.length + page.tickets.length < page.totalCount,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final ticketsProvider = NotifierProvider<TicketsNotifier, TicketsState>(TicketsNotifier.new);
