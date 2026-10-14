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

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final ClientNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTicket = notification.type == 'ticket';
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
                Text(
                  isTicket ? '#${notification.ticketDisplayId} ${notification.ticketTitle}' : 'Chat com a equipe',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
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
