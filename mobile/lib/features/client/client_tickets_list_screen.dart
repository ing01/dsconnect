import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/widgets/bordered_card.dart';
import '../../core/widgets/pill_label.dart';
import 'client_ticket_create_screen.dart';
import 'client_ticket_detail_screen.dart';
import 'models/client_ticket.dart';
import 'providers/client_providers.dart';

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
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _TicketTile(ticket: tickets[index]),
            );
          },
        ),
      ),
      floatingActionButton: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: brandGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2781F6).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientTicketCreateScreen()),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Abrir chamado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final ClientTicket ticket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BorderedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: ticket.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${ticket.displayId} ${ticket.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd/MM/yy').format(ticket.updatedAt.toLocal()),
                style: TextStyle(fontSize: 11, color: colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ticket.pendingTriage ? 'Aguardando triagem' : '${ticket.teamName} · ${ticket.ticketColumnName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              if (ticket.pendingTriage) const PillLabel('Aguardando triagem', colorName: 'amber'),
              PillLabel(statusLabels[ticket.status] ?? ticket.status, colorName: statusColorName(ticket.status)),
              PillLabel(
                priorityLabels[ticket.priority] ?? ticket.priority,
                colorName: priorityColorName(ticket.priority),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
