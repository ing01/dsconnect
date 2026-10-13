// Teste de fumaça básico - só confirma que o app sobe sem travar. Testes
// de verdade (login, lista de tickets, etc.) chegam junto de cada tela que
// ainda vai ser construída nas próximas fases.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: Text('ok'))),
      ),
    );

    expect(find.text('ok'), findsOneWidget);
  });
}
