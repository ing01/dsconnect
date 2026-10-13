import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ticket_column.dart';
import '../models/ticket_detail.dart';
import 'tickets_providers.dart';

// Um ticket por vez, mantido vivo so' enquanto a tela de detalhe estiver
// aberta - por isso `autoDispose` (ver `.autoDispose.family` abaixo),
// diferente da lista "Meus tickets" (essa sim fica viva o tempo todo,
// trocando de Mesa sem perder o que ja carregou).
//
// Riverpod 3: o argumento do `family` nao chega dentro de `build()` (que
// continua sem parametro nenhum) - ele e' capturado no CONSTRUTOR do
// notifier, que a fabrica do `family` recebe.
class TicketDetailNotifier extends AsyncNotifier<TicketDetail> {
  TicketDetailNotifier(this.ticketId);

  final int ticketId;

  @override
  Future<TicketDetail> build() async {
    final accountId = ref.read(currentAccountIdProvider);
    if (accountId == null) throw StateError('Sem conta selecionada');
    return ref.read(ticketsRepositoryProvider).fetchDetail(accountId, ticketId);
  }

  Future<void> changeStatus(String action, {String? reason}) async {
    final accountId = ref.read(currentAccountIdProvider);
    if (accountId == null) return;

    final previous = state;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ticketsRepositoryProvider).changeStatus(accountId, ticketId, action, reason: reason),
    );
    // Uma falha (ex: "fechar" recusado por faltar requisito) volta pro
    // ticket como estava, em vez de deixar a tela num estado de erro so'
    // porque uma acao pontual nao deu certo.
    if (state.hasError) state = previous;
  }

  Future<void> moveToColumn(int columnId) async {
    final accountId = ref.read(currentAccountIdProvider);
    if (accountId == null) return;

    final previous = state;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ticketsRepositoryProvider).moveToColumn(accountId, ticketId, columnId),
    );
    if (state.hasError) state = previous;
  }
}

final ticketDetailProvider = AsyncNotifierProvider.autoDispose.family<TicketDetailNotifier, TicketDetail, int>(
  TicketDetailNotifier.new,
);

// Os Estagios da Mesa do ticket aberto - pra popular o seletor de "mover
// pra". Chaveado pelo `teamId`, nao pelo ticket, porque varios tickets da
// mesma Mesa reaproveitam a mesma lista.
final teamColumnsProvider = FutureProvider.autoDispose.family<List<TicketColumn>, int>((ref, teamId) async {
  final accountId = ref.read(currentAccountIdProvider);
  if (accountId == null) return const [];
  return ref.read(ticketsRepositoryProvider).fetchColumns(accountId, teamId);
});
