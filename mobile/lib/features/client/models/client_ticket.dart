// Um chamado como o CLIENTE o ve - bem mais enxuto que o do colaborador
// (sem responsavel, SLA, impedimento, etc. - ver api/v1/client/models/_ticket
// no servidor).
class ClientTicket {
  const ClientTicket({
    required this.id,
    required this.displayId,
    required this.title,
    required this.description,
    required this.status,
    required this.pendingTriage,
    required this.priority,
    required this.ticketColumnName,
    required this.teamName,
    this.categoryName,
    required this.createdAt,
    required this.updatedAt,
    this.requestedBy,
    required this.requestedByMe,
  });

  final int id;
  final int displayId;
  final String title;
  final String description;
  final String status;
  final bool pendingTriage;
  final String priority;
  final String ticketColumnName;
  final String teamName;
  final String? categoryName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? requestedBy;
  final bool requestedByMe;

  factory ClientTicket.fromJson(Map<String, dynamic> json) => ClientTicket(
        id: json['id'] as int,
        displayId: json['display_id'] as int,
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        pendingTriage: (json['pending_triage'] as bool?) ?? false,
        priority: (json['priority'] as String?) ?? '',
        ticketColumnName: (json['ticket_column_name'] as String?) ?? '',
        teamName: (json['team_name'] as String?) ?? '',
        categoryName: json['category_name'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((json['created_at'] as int?) ?? 0) * 1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(((json['updated_at'] as int?) ?? 0) * 1000),
        requestedBy: json['requested_by'] as String?,
        requestedByMe: (json['requested_by_me'] as bool?) ?? false,
      );
}
