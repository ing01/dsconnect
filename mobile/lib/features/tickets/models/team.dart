// Uma Mesa (Time) - so' o que a lista/filtro de tickets precisa, nao a
// configuracao inteira que o painel web usa.
class Team {
  const Team({required this.id, required this.name});

  final int id;
  final String name;

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
      );
}
