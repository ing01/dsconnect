import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ticket_detail.dart';
import 'providers/ticket_detail_providers.dart';

const _statusLabels = {
  'open': 'Aberto',
  'resolved': 'Resolvido',
  'closed': 'Fechado',
  'cancelled': 'Cancelado',
};

const _priorityLabels = {
  'urgent': 'Urgente',
  'high': 'Alta',
  'medium': 'Média',
  'low': 'Baixa',
};

class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({required this.ticketId, super.key});

  final int ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(ticketDetailProvider(ticketId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ticketAsync.value != null ? '#${ticketAsync.value!.displayId ?? ticketId}' : 'Ticket',
        ),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar este ticket.\n$error', textAlign: TextAlign.center),
          ),
        ),
        data: (ticket) => _TicketDetailBody(ticket: ticket),
      ),
    );
  }
}

class _TicketDetailBody extends ConsumerWidget {
  const _TicketDetailBody({required this.ticket});

  final TicketDetail ticket;

  Future<void> _runAction(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    await action();
    final error = ref.read(ticketDetailProvider(ticket.id)).error;
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ticketDetailProvider(ticket.id).notifier);
    final columnsAsync = ref.watch(teamColumnsProvider(ticket.teamId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(ticket.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text(_statusLabels[ticket.status] ?? ticket.status)),
            Chip(label: Text(_priorityLabels[ticket.priority] ?? ticket.priority)),
          ],
        ),
        const SizedBox(height: 16),
        _InfoRow(label: 'Mesa', value: ticket.teamName),
        columnsAsync.when(
          data: (columns) => _InfoRow(
            label: 'Estágio',
            value: ticket.ticketColumnName,
            trailing: columns.isEmpty
                ? null
                : PopupMenuButton<int>(
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    tooltip: 'Mover para outro Estágio',
                    onSelected: (columnId) => _runAction(context, ref, () => notifier.moveToColumn(columnId)),
                    itemBuilder: (_) => [
                      for (final column in columns)
                        PopupMenuItem(value: column.id, child: Text(column.name)),
                    ],
                  ),
          ),
          loading: () => _InfoRow(label: 'Estágio', value: ticket.ticketColumnName),
          error: (_, _) => _InfoRow(label: 'Estágio', value: ticket.ticketColumnName),
        ),
        if (ticket.assigneeName != null) _InfoRow(label: 'Responsável', value: ticket.assigneeName!),
        if (ticket.companyName != null) _InfoRow(label: 'Empresa', value: ticket.companyName!),
        if (ticket.contactName != null) _InfoRow(label: 'Solicitante', value: ticket.contactName!),
        if (ticket.contactEmail != null) _InfoRow(label: 'E-mail', value: ticket.contactEmail!),
        if (ticket.contactPhone != null) _InfoRow(label: 'Telefone', value: ticket.contactPhone!),
        const Divider(height: 32),
        Text('Descrição', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(ticket.description),
        const SizedBox(height: 24),
        if (ticket.canUpdate) _StatusActions(ticket: ticket, onAction: (a) => _runAction(context, ref, a)),
      ],
    );
  }
}

class _StatusActions extends ConsumerWidget {
  const _StatusActions({required this.ticket, required this.onAction});

  final TicketDetail ticket;
  final void Function(Future<void> Function()) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cada status so' oferece as transicoes validas a partir dele - as
    // mesmas que o painel web permite (ver TicketsController#resolve/
    // reopen/close/cancel no servidor, que recusa qualquer outra).
    final notifier = ref.read(ticketDetailProvider(ticket.id).notifier);

    final buttons = <Widget>[];
    if (ticket.status == 'open') {
      buttons.add(FilledButton.icon(
        onPressed: () => onAction(() => notifier.changeStatus('resolve')),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Resolver'),
      ));
      buttons.add(OutlinedButton.icon(
        onPressed: () => onAction(() => notifier.changeStatus('close')),
        icon: const Icon(Icons.lock_outline),
        label: const Text('Fechar'),
      ));
      buttons.add(TextButton.icon(
        onPressed: () => onAction(() => notifier.changeStatus('cancel')),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancelar'),
      ));
    } else {
      buttons.add(OutlinedButton.icon(
        onPressed: () => onAction(() => notifier.changeStatus('reopen')),
        icon: const Icon(Icons.replay),
        label: const Text('Reabrir'),
      ));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          Expanded(child: Text(value)),
          ?trailing,
        ],
      ),
    );
  }
}
