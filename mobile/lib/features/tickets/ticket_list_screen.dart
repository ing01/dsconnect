import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models/ticket_summary.dart';
import 'providers/tickets_providers.dart';
import 'ticket_detail_screen.dart';

// A cor do carinha de prioridade - mesma ideia visual do Kanban web, so que
// num ponto pequeno em vez de uma borda colorida (a lista e' densa demais
// pra isso aqui).
const _priorityColors = {
  'urgent': Colors.red,
  'high': Colors.orange,
  'medium': Colors.amber,
  'low': Colors.blueGrey,
};

const _statusLabels = {
  'open': 'Aberto',
  'resolved': 'Resolvido',
  'closed': 'Fechado',
  'cancelled': 'Cancelado',
};

class TicketListScreen extends ConsumerWidget {
  const TicketListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ticketsProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final selectedTeamId = ref.watch(selectedTeamIdProvider);

    return Column(
      children: [
        teamsAsync.when(
          data: (teams) {
            if (teams.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _TeamChip(
                      label: 'Todas as Mesas',
                      selected: selectedTeamId == null,
                      onTap: () => ref.read(selectedTeamIdProvider.notifier).select(null),
                    ),
                    for (final team in teams)
                      _TeamChip(
                        label: team.name,
                        selected: selectedTeamId == team.id,
                        onTap: () => ref.read(selectedTeamIdProvider.notifier).select(team.id),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(ticketsProvider.notifier).refresh(),
            child: _buildBody(context, ref, state),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, TicketsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(state.error!, textAlign: TextAlign.center),
        ],
      );
    }
    if (state.tickets.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Nenhum ticket atribuído a você aqui.')),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final nearBottom = notification.metrics.pixels > notification.metrics.maxScrollExtent - 200;
        if (nearBottom) ref.read(ticketsProvider.notifier).loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.tickets.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= state.tickets.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _TicketTile(ticket: state.tickets[index]);
        },
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final TicketSummary ticket;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticket.id)),
      ),
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: _priorityColors[ticket.priority] ?? Colors.grey,
      ),
      title: Text(
        ticket.displayId != null ? '#${ticket.displayId} ${ticket.title}' : ticket.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${ticket.teamName} · ${ticket.ticketColumnName}'
        '${ticket.companyName != null ? ' · ${ticket.companyName}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_statusLabels[ticket.status] ?? ticket.status, style: const TextStyle(fontSize: 12)),
          Text(
            DateFormat('dd/MM HH:mm').format(ticket.updatedAt.toLocal()),
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
