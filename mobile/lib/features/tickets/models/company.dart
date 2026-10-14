// Uma Empresa, pro filtro da lista de tickets do colaborador (ver
// `Api::V1::Accounts::CompaniesController#index` no servidor).
class Company {
  const Company({required this.id, required this.name});

  final int id;
  final String name;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
      );
}
