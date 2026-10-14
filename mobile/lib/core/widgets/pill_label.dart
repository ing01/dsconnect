import 'package:flutter/material.dart';

import '../theme/semantic_colors.dart';

// A mesma pilula do `Label.vue` (components-next) do painel web - fundo
// claro da cor + texto na mesma cor, cantos totalmente arredondados.
class PillLabel extends StatelessWidget {
  const PillLabel(this.text, {required this.colorName, super.key});

  final String text;
  final String colorName;

  @override
  Widget build(BuildContext context) {
    final color = semanticColor(colorName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(color: color.foreground, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
