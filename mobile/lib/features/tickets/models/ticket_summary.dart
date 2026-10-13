// Os campos que a LISTA de tickets mostra - o mesmo `_ticket.json.jbuilder`
// do servidor traz dezenas de campos (ver o modelo completo no painel web),
// mas a lista do celular so' precisa destes pra renderizar o cartao.
class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.displayId,
    required this.title,
    required this.status,
    required this.priority,
    required this.teamName,
    required this.ticketColumnName,
    this.assigneeName,
    this.requesterName,
    this.companyName,
    required this.updatedAt,
  });

  final int id;
  final int? displayId;
  final String title;
  final String status;
  final String priority;
  final String teamName;
  final String ticketColumnName;
  final String? assigneeName;
  final String? requesterName;
  final String? companyName;
  final DateTime updatedAt;

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
        id: json['id'] as int,
        displayId: json['display_id'] as int?,
        title: (json['title'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        priority: (json['priority'] as String?) ?? '',
        teamName: (json['team_name'] as String?) ?? '',
        ticketColumnName: (json['ticket_column_name'] as String?) ?? '',
        assigneeName: json['assignee_name'] as String?,
        requesterName: json['requester_name'] as String?,
        companyName: json['company_name'] as String?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(((json['updated_at'] as int?) ?? 0) * 1000),
      );
}
