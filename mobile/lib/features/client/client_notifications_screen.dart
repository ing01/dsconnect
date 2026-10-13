import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'client_ticket_detail_screen.dart';
import 'models/client_notification.dart';
import 'providers/client_providers.dart';

class ClientNotificationsScreen extends ConsumerWidget {
  const ClientNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(clientNotificationsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(clientNotificationsProvider.future),
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: const [SizedBox(height: 80), Center(child: Text('Não foi possível carregar.'))],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [SizedBox(height: 80), Center(child: Text('Nenhuma novidade por aqui ainda.'))],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _NotificationTile(notification: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final ClientNotification notification;

  @override
  Widget build(BuildContext context) {
    final isTicket = notification.type == 'ticket';

    return ListTile(
      leading: Icon(isTicket ? Icons.confirmation_number_outlined : Icons.chat_bubble_outline),
      title: Text(isTicket ? '#${notification.ticketDisplayId} ${notification.ticketTitle}' : 'Chat com a equipe'),
      subtitle: Text(notification.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        DateFormat('dd/MM HH:mm').format(notification.createdAt.toLocal()),
        style: const TextStyle(fontSize: 11),
      ),
      onTap: isTicket && notification.ticketId != null
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: notification.ticketId!)),
              )
          : null,
    );
  }
}
