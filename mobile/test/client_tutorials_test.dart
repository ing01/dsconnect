import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duedesk_mobile/features/client/client_tutorials_screen.dart';
import 'package:duedesk_mobile/features/client/models/client_tutorial.dart';
import 'package:duedesk_mobile/features/client/providers/client_providers.dart';

TutorialsResult _result({required List<Map<String, dynamic>> modules, required List<Map<String, dynamic>> tutorials}) =>
    TutorialsResult.fromJson({'modules': modules, 'tutorials': tutorials});

Widget _app(TutorialsResult result) => ProviderScope(
      overrides: [clientTutorialsProvider.overrideWith((ref) async => result)],
      child: const MaterialApp(home: ClientTutorialsScreen()),
    );

void main() {
  group('TutorialsResult.cards', () {
    test('so modulos com video viram card, e o video solto vai para "Geral"', () {
      final result = _result(
        modules: [
          {'id': 1, 'name': 'DS Connect'},
          {'id': 2, 'name': 'Sem video'},
        ],
        tutorials: [
          {'id': 10, 'module_id': 1, 'title': 'Abrir chamado'},
          {'id': 11, 'module_id': null, 'title': 'Primeiros passos'},
        ],
      );

      expect(result.cards.map((card) => card.name), ['DS Connect', 'Geral']);
      expect(result.cards.first.count, 1);
    });

    test('sem nenhum modulo com video, nao ha cards (a lista aparece direto)', () {
      final result = _result(
        modules: const [],
        tutorials: [
          {'id': 11, 'module_id': null, 'title': 'Primeiros passos'},
        ],
      );

      expect(result.cards, isEmpty);
    });

    test('o arquivo enviado tem prioridade sobre o link', () {
      final tutorial = ClientTutorial.fromJson({
        'id': 1,
        'title': 'x',
        'video_url': 'https://youtu.be/abcdefghijk',
        'video_file_url': 'https://exemplo.test/video.mp4',
      });

      expect(tutorial.videoAddress, 'https://exemplo.test/video.mp4');
    });
  });

  group('ClientTutorialsScreen', () {
    testWidgets('mostra os modulos como cards e abre os videos ao tocar', (tester) async {
      await tester.pumpWidget(_app(_result(
        modules: [
          {'id': 1, 'name': 'DS Connect', 'description': 'O sistema'},
        ],
        tutorials: [
          {'id': 10, 'module_id': 1, 'title': 'Abrir chamado', 'video_url': 'https://youtu.be/abcdefghijk'},
        ],
      )));
      await tester.pumpAndSettle();

      expect(find.text('DS Connect'), findsOneWidget);
      expect(find.text('Abrir chamado'), findsNothing);

      await tester.tap(find.text('DS Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir chamado'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir chamado'), findsNothing);
    });

    testWidgets('sem modulos, lista os videos direto, recolhidos', (tester) async {
      await tester.pumpWidget(_app(_result(
        modules: const [],
        tutorials: [
          {'id': 10, 'module_id': null, 'title': 'Primeiros passos', 'description': 'Comece por aqui', 'video_url': 'https://youtu.be/abcdefghijk'},
        ],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Primeiros passos'), findsOneWidget);
      expect(find.text('Assistir vídeo'), findsNothing);

      await tester.tap(find.text('Primeiros passos'));
      await tester.pumpAndSettle();

      expect(find.text('Comece por aqui'), findsOneWidget);
      expect(find.text('Assistir vídeo'), findsOneWidget);
    });

    testWidgets('avisa quando nao ha tutoriais', (tester) async {
      await tester.pumpWidget(_app(_result(modules: const [], tutorials: const [])));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum tutorial disponível por enquanto.'), findsOneWidget);
    });
  });
}
