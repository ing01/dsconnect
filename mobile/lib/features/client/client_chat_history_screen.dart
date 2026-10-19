import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'client_chat_history_detail_screen.dart';
import 'providers/client_providers.dart';

class ClientChatHistoryScreen extends ConsumerWidget {
  const ClientChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(chatHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de conversas')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar o histórico.'),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.invalidate(chatHistoryProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma conversa encerrada ainda.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final resolvedAt =
                  DateFormat('dd/MM/yyyy HH:mm').format(session.resolvedAt.toLocal());
              return ListTile(
                title: Text(
                  session.preview.isNotEmpty ? session.preview : '(sem mensagens)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('Encerrada em $resolvedAt'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ClientChatHistoryDetailScreen(sessionId: session.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
