import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/bordered_card.dart';
import 'client_chat_screen.dart';
import 'client_ticket_detail_screen.dart';
import 'models/client_notification.dart';
import 'providers/client_providers.dart';

class ClientNotificationsScreen extends ConsumerWidget {
  const ClientNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(clientNotificationsProvider);
    final dismissedAsync = ref.watch(dismissedNotificationsProvider);
    final dismissed = dismissedAsync.value ?? const {};

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(clientNotificationsProvider.future),
        child: notificationsAsync.when(
          // A lista se atualiza sozinha de tempos em tempos: sem isto cada
          // atualizacao piscaria o indicador de carregamento no meio da leitura.
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          skipError: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: const [SizedBox(height: 80), Center(child: Text('Não foi possível carregar.'))],
          ),
          data: (allItems) {
            final items = allItems.where((item) => !dismissed.contains(item.id)).toList();
            if (items.isEmpty) {
              return ListView(
                children: const [SizedBox(height: 80), Center(child: Text('Nenhuma novidade por aqui ainda.'))],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _NotificationTile(notification: items[index]),
            );
          },
        ),
      ),
    );
  }
}

// "Maria respondeu no chat" / "Maria respondeu no chamado #12": quem, o que e
// onde numa frase so. Sem autor (mensagem de bot, usuario removido), "A equipe".
String _headline(ClientNotification notification) {
  final author = notification.authorName?.trim();
  final who = (author == null || author.isEmpty) ? 'A equipe' : author;

  if (notification.isTicketMoved) return 'Chamado #${notification.ticketDisplayId} foi encaminhado';

  return notification.type == 'ticket'
      ? '$who respondeu no chamado #${notification.ticketDisplayId}'
      : '$who respondeu no chat';
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final ClientNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTicket = notification.isTicketRelated;
    final colorScheme = Theme.of(context).colorScheme;

    return BorderedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () {
        ref.read(dismissedNotificationsProvider.notifier).dismiss(notification.id);
        if (isTicket && notification.ticketId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: notification.ticketId!)),
          );
        } else if (!isTicket) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClientChatScreen()));
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isTicket ? Icons.confirmation_number_outlined : Icons.chat_bubble_outline,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // O titulo diz o que aconteceu - "respondeu" - e onde, para o
                // cliente entender de relance que a equipe falou com ele.
                Text(
                  _headline(notification),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (isTicket && notification.ticketTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    notification.ticketTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.primary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  notification.preview.isEmpty ? 'Toque para ver' : notification.preview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  isTicket ? 'Toque para abrir o chamado' : 'Toque para abrir o chat',
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('dd/MM HH:mm').format(notification.createdAt.toLocal()),
            style: TextStyle(fontSize: 11, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
