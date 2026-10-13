// Um Estagio (coluna do Kanban) de uma Mesa - so' o que o seletor de
// "mover pra outro Estagio" da tela de detalhe precisa.
class TicketColumn {
  const TicketColumn({required this.id, required this.name});

  final int id;
  final String name;

  factory TicketColumn.fromJson(Map<String, dynamic> json) => TicketColumn(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
      );
}
