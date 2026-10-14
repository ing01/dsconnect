import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/widgets/bordered_card.dart';
import '../../core/widgets/pill_label.dart';
import 'models/client_ticket_detail.dart';
import 'models/ticket_communication.dart';
import 'providers/client_providers.dart';

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
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não foi possível carregar este chamado.\n${describeApiError(error)}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
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
  final List<XFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    // Some a notificacao desse chamado tambem quando ele e' aberto por outro
    // caminho (ex.: a lista "Meus chamados"), nao so clicando na notificacao.
    Future.microtask(
      () => ref.read(dismissedNotificationsProvider.notifier).dismissForTicket(widget.ticketId),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      setState(() => _attachments.add(file));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível acessar a câmera/galeria. Confira a permissão do app.')),
        );
      }
    }
  }

  Future<void> _send() async {
    final body = _replyController.text.trim();
    // O servidor exige texto mesmo quando tem anexo (so' o anexo sozinho nao
    // basta) - ver `Api::V1::Client::CommunicationsController#create`.
    if (body.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(clientTicketDetailProvider(widget.ticketId).notifier)
          .reply(body, attachments: _attachments);
      _replyController.clear();
      setState(() => _attachments.clear());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.detail.ticket;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            reverse: false,
            children: [
              Text('#${ticket.displayId}', style: TextStyle(fontSize: 12, color: colorScheme.outline)),
              Text(ticket.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (ticket.pendingTriage) const PillLabel('Aguardando triagem', colorName: 'amber'),
                  PillLabel(statusLabels[ticket.status] ?? ticket.status, colorName: statusColorName(ticket.status)),
                  PillLabel(
                    priorityLabels[ticket.priority] ?? ticket.priority,
                    colorName: priorityColorName(ticket.priority),
                  ),
                  if (ticket.categoryName != null) PillLabel(ticket.categoryName!, colorName: 'slate'),
                ],
              ),
              const SizedBox(height: 16),
              BorderedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descrição',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(ticket.description, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Conversa', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
        if (ticket.status == 'open')
          _ReplyBar(
            controller: _replyController,
            isSending: _isSending,
            onSend: _send,
            attachments: _attachments,
            onPickImage: _pickImage,
            onRemoveAttachment: (file) => setState(() => _attachments.remove(file)),
          ),
      ],
    );
  }
}

// O mesmo cartao "article" da aba Comunicacao do Portal web - cheio da
// largura, com um contorno na cor da marca do lado de quem respondeu (o
// cliente), em vez de bolhas de chat espremidas num canto.
class _CommunicationBubble extends StatelessWidget {
  const _CommunicationBubble({required this.communication});

  final TicketCommunication communication;

  @override
  Widget build(BuildContext context) {
    final isFromMe = communication.isFromMe;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFromMe ? colorScheme.primary.withValues(alpha: 0.06) : null,
          border: Border.all(
            color: isFromMe ? colorScheme.primary.withValues(alpha: 0.35) : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isFromMe ? 'Você' : (communication.authorName ?? 'Equipe'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM HH:mm').format(communication.createdAt.toLocal()),
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(communication.body, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.attachments,
    required this.onPickImage,
    required this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final List<XFile> attachments;
  final void Function(ImageSource source) onPickImage;
  final void Function(XFile file) onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final file in attachments)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(file.path), width: 48, height: 48, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () => onRemoveAttachment(file),
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: Theme.of(context).colorScheme.error,
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: () => onPickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  tooltip: 'Tirar foto',
                ),
                IconButton(
                  onPressed: () => onPickImage(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'Galeria',
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Escreva uma mensagem...', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                GradientIconButton(
                  onPressed: isSending ? null : onSend,
                  icon: isSending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
