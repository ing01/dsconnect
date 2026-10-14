import 'package:flutter/material.dart';

// Mesmas cores semanticas do `Label.vue` do painel web (slate/amber/teal/
// ruby/blue) - pra status e prioridade baterem visualmente com o Portal.
class SemanticColor {
  const SemanticColor(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

const _palette = {
  'blue': SemanticColor(Color(0xFF0B61A4), Color(0xFFE3F2FD)),
  'teal': SemanticColor(Color(0xFF0D7D72), Color(0xFFE0F5F2)),
  'amber': SemanticColor(Color(0xFF9A6700), Color(0xFFFFF4D6)),
  'ruby': SemanticColor(Color(0xFFC2185B), Color(0xFFFDE7EE)),
  'slate': SemanticColor(Color(0xFF55606B), Color(0xFFEDEFF1)),
};

SemanticColor semanticColor(String name) => _palette[name] ?? _palette['slate']!;

// Ver `ticketLabels.js` (STATUS_LABEL_COLORS/PRIORITY_LABEL_COLORS) - mesmo
// mapeamento, pra um chamado "aberto" aparecer azul nos dois lugares.
const _statusColorNames = {'open': 'blue', 'resolved': 'teal', 'closed': 'slate', 'cancelled': 'slate'};
const _priorityColorNames = {'low': 'slate', 'medium': 'blue', 'high': 'amber', 'urgent': 'ruby'};

String statusColorName(String status) => _statusColorNames[status] ?? 'slate';
String priorityColorName(String priority) => _priorityColorNames[priority] ?? 'slate';

const statusLabels = {
  'open': 'Aberto',
  'resolved': 'Resolvido',
  'closed': 'Fechado',
  'cancelled': 'Cancelado',
};

const priorityLabels = {
  'urgent': 'Urgente',
  'high': 'Alta',
  'medium': 'Média',
  'low': 'Baixa',
};
