class TicketCategory {
  const TicketCategory({required this.id, required this.name, required this.requireAttachment});

  final int id;
  final String name;
  final bool requireAttachment;

  factory TicketCategory.fromJson(Map<String, dynamic> json) => TicketCategory(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        requireAttachment: (json['require_attachment'] as bool?) ?? false,
      );
}
