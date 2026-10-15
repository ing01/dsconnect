// Uma opcao de filtro (Mesa, Estagio ou Responsavel) - todas vem do servidor
// no mesmo formato {id, name}, so' com nomes de campo diferentes.
class FilterOption {
  const FilterOption({required this.id, required this.name});

  final int id;
  final String name;

  factory FilterOption.fromJson(Map<String, dynamic> json) => FilterOption(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
      );
}
