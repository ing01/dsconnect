// Um chamado como o CLIENTE o ve - bem mais enxuto que o do colaborador
// (sem SLA, impedimento, etc. - ver api/v1/client/models/_ticket no
// servidor). O nome do responsavel e' a excecao: o cliente precisa saber
// quem esta cuidando do chamado dele.
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
    this.assigneeName,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
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
  final String? assigneeName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
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
        assigneeName: json['assignee_name'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((json['created_at'] as int?) ?? 0) * 1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(((json['updated_at'] as int?) ?? 0) * 1000),
        dueDate: _parseDueDate(json['due_date']),
        requestedBy: json['requested_by'] as String?,
        requestedByMe: (json['requested_by_me'] as bool?) ?? false,
      );
}

// A lista "Meus chamados" e o detalhe do chamado vem de dois jbuilders
// diferentes no servidor, e cada um manda `due_date` num formato - a lista
// usa o partial interno (ISO 8601, ex. "2026-10-20T00:00:00Z"), o detalhe
// usa o partial do cliente (epoch em segundos). Aceita os dois pra nao
// quebrar nenhuma das duas telas.
DateTime? _parseDueDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  if (value is String) return DateTime.tryParse(value);
  return null;
}
