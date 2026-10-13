import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models/client_ticket_detail.dart';
import 'models/ticket_communication.dart';
import 'providers/client_providers.dart';

const _statusLabels = {
  'open': 'Aberto',
  'resolved': 'Resolvido',
  'closed': 'Fechado',
  'cancelled': 'Cancelado',
};

class ClientTicketDetailScreen extends ConsumerWidget {
  const ClientTicketDetailScreen({required this.ticketId, super.key});

  final int ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(clientTicketDetailProvider(ticketId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detailAsync.value != null ? '#${detailAsync.value!.ticket.displayId}' : 'Chamado'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text('Não foi possível carregar este chamado.')),
        data: (detail) => _TicketDetailBody(ticketId: ticketId, detail: detail),
      ),
    );
  }
}

class _TicketDetailBody extends ConsumerStatefulWidget {
  const _TicketDetailBody({required this.ticketId, required this.detail});

  final int ticketId;
  final ClientTicketDetail detail;

  @override
  ConsumerState<_TicketDetailBody> createState() => _TicketDetailBodyState();
}

class _TicketDetailBodyState extends ConsumerState<_TicketDetailBody> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _replyController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(clientTicketDetailProvider(widget.ticketId).notifier).reply(body);
      _replyController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar sua mensagem.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.detail.ticket;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            reverse: false,
            children: [
              Text(ticket.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(_statusLabels[ticket.status] ?? ticket.status)),
                  if (ticket.pendingTriage) const Chip(label: Text('Aguardando triagem')),
                  if (ticket.categoryName != null) Chip(label: Text(ticket.categoryName!)),
                ],
              ),
              const SizedBox(height: 16),
              Text(ticket.description),
              const Divider(height: 32),
              Text('Conversa', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (widget.detail.communications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nenhuma mensagem ainda.'),
                )
              else
                // O servidor manda do mais recente pro mais antigo; a tela
                // le de cima pra baixo como uma conversa normal.
                for (final communication in widget.detail.communications.reversed)
                  _CommunicationBubble(communication: communication),
            ],
          ),
        ),
        if (ticket.status == 'open') _ReplyBar(controller: _replyController, isSending: _isSending, onSend: _send),
      ],
    );
  }
}

class _CommunicationBubble extends StatelessWidget {
  const _CommunicationBubble({required this.communication});

  final TicketCommunication communication;

  @override
  Widget build(BuildContext context) {
    final isFromMe = communication.isFromMe;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isFromMe ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromMe)
              Text(
                communication.authorName ?? 'Equipe',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            Text(communication.body),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM HH:mm').format(communication.createdAt.toLocal()),
              style: TextStyle(fontSize: 10, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.controller, required this.isSending, required this.onSend});

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Escreva uma mensagem...', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
