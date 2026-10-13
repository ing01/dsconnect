// Uma mensagem da aba Comunicacao do chamado - o que a equipe escreveu
// (`outbound`) e o que o proprio cliente respondeu (`inbound`), na mesma
// lista.
class TicketCommunication {
  const TicketCommunication({
    required this.id,
    required this.direction,
    required this.body,
    this.authorName,
    required this.createdAt,
  });

  final int id;
  final String direction;
  final String body;
  final String? authorName;
  final DateTime createdAt;

  bool get isFromMe => direction == 'inbound';

  factory TicketCommunication.fromJson(Map<String, dynamic> json) => TicketCommunication(
        id: json['id'] as int,
        direction: (json['direction'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        authorName: json['author_name'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((json['created_at'] as int?) ?? 0) * 1000),
      );
}
