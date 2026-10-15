// Uma opcao de filtro (Mesa, Estagio ou Responsavel) - todas vem do servidor
// no mesmo formato {id, name}, so' com nomes de campo diferentes. Estagio
// traz tambem `team_id` - Mesas diferentes podem ter Estagio com o mesmo
// nome (ex.: "Pendente"), e e' o `teamId` que permite distinguir/filtrar.
class FilterOption {
  const FilterOption({required this.id, required this.name, this.teamId});

  final int id;
  final String name;
  final int? teamId;

  factory FilterOption.fromJson(Map<String, dynamic> json) => FilterOption(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        teamId: json['team_id'] as int?,
      );
}
