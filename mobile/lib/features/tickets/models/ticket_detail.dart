// Os campos que a tela de DETALHE mostra, alem do que `TicketSummary` ja
// tem - a resposta completa do servidor (`_ticket_detail.json.jbuilder`) traz
// bem mais que isso (anexos, atividades, SLA...), que fica pra uma proxima
// etapa.
class TicketDetail {
  const TicketDetail({
    required this.id,
    required this.displayId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.teamId,
    required this.teamName,
    required this.ticketColumnId,
    required this.ticketColumnName,
    this.assigneeName,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.companyName,
    this.dueDate,
    required this.canUpdate,
  });

  final int id;
  final int? displayId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final int teamId;
  final String teamName;
  final int ticketColumnId;
  final String ticketColumnName;
  final String? assigneeName;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? companyName;
  final DateTime? dueDate;
  final bool canUpdate;

  factory TicketDetail.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'] as Map<String, dynamic>?;
    return TicketDetail(
      id: json['id'] as int,
      displayId: json['display_id'] as int?,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      priority: (json['priority'] as String?) ?? '',
      teamId: json['team_id'] as int,
      teamName: (json['team_name'] as String?) ?? '',
      ticketColumnId: json['ticket_column_id'] as int,
      ticketColumnName: (json['ticket_column_name'] as String?) ?? '',
      assigneeName: json['assignee_name'] as String?,
      contactName: contact?['name'] as String?,
      contactEmail: contact?['email'] as String?,
      contactPhone: contact?['phone_number'] as String?,
      companyName: json['company_name'] as String?,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null,
      canUpdate: (json['can_update'] as bool?) ?? false,
    );
  }
}
