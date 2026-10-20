import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models/chat_message.dart';
import 'providers/client_providers.dart';

class ClientChatHistoryDetailScreen extends ConsumerWidget {
  const ClientChatHistoryDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(chatHistoryDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Conversa encerrada')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar a conversa.'),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(chatHistoryDetailProvider(sessionId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (detail) {
          final resolvedAt =
              DateFormat('dd/MM/yyyy HH:mm').format(detail.resolvedAt.toLocal());
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Encerrada em $resolvedAt',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: detail.messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Sem mensagens nesta conversa.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: detail.messages.length,
                        itemBuilder: (context, index) =>
                            _HistoryBubble(message: detail.messages[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryBubble extends StatelessWidget {
  const _HistoryBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment:
          message.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: message.fromMe
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.fromMe && message.authorName != null)
              Text(
                message.authorName!,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary),
              ),
            if (message.content.isNotEmpty) Text(message.content),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt.toLocal()),
              style: TextStyle(fontSize: 10, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
