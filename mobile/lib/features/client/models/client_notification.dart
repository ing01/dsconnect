// Uma novidade do cliente - resposta da equipe num chamado, ou no chat do
// Portal (ver api/v1/client/notifications, que junta as duas fontes).
class ClientNotification {
  const ClientNotification({
    required this.id,
    required this.type,
    this.ticketId,
    this.ticketDisplayId,
    this.ticketTitle,
    required this.preview,
    this.authorName,
    required this.createdAt,
  });

  final String id;
  final String type; // 'ticket' ou 'chat'
  final int? ticketId;
  final int? ticketDisplayId;
  final String? ticketTitle;
  final String preview;
  final String? authorName;
  final DateTime createdAt;

  factory ClientNotification.fromJson(Map<String, dynamic> json) => ClientNotification(
        id: json['id'] as String,
        type: (json['type'] as String?) ?? '',
        ticketId: json['ticket_id'] as int?,
        ticketDisplayId: json['ticket_display_id'] as int?,
        ticketTitle: json['ticket_title'] as String?,
        preview: (json['preview'] as String?) ?? '',
        authorName: json['author_name'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((json['created_at'] as int?) ?? 0) * 1000),
      );
}
