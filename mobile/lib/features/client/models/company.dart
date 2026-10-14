// Uma Empresa do proprio contato - usada so' pro filtro da lista "Meus
// chamados" (ver `client_companies` no servidor: so' aparece quem tem mais
// de uma).
class Company {
  const Company({required this.id, required this.name});

  final int id;
  final String name;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
      );
}
