import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'client_ticket_create_screen.dart';
import 'client_ticket_detail_screen.dart';
import 'models/client_ticket.dart';
import 'providers/client_providers.dart';

const _statusLabels = {
  'open': 'Aberto',
  'resolved': 'Resolvido',
  'closed': 'Fechado',
  'cancelled': 'Cancelado',
};

const _priorityColors = {
  'urgent': Colors.red,
  'high': Colors.orange,
  'medium': Colors.amber,
  'low': Colors.blueGrey,
};

class ClientTicketsListScreen extends ConsumerWidget {
  const ClientTicketsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(clientTicketsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientTicketsProvider.notifier).refresh(),
        child: ticketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Center(child: Text('Não foi possível carregar seus chamados.')),
            ],
          ),
          data: (tickets) {
            if (tickets.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Você ainda não tem nenhum chamado aberto.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _TicketTile(ticket: tickets[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ClientTicketCreateScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Abrir chamado'),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final ClientTicket ticket;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: ticket.id)),
      ),
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: _priorityColors[ticket.priority] ?? Colors.grey,
      ),
      title: Text('#${ticket.displayId} ${ticket.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        ticket.pendingTriage ? 'Aguardando triagem' : '${ticket.teamName} · ${ticket.ticketColumnName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_statusLabels[ticket.status] ?? ticket.status, style: const TextStyle(fontSize: 12)),
          Text(
            DateFormat('dd/MM/yy').format(ticket.updatedAt.toLocal()),
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
