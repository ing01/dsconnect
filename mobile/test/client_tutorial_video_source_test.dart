import 'package:flutter_test/flutter_test.dart';

import 'package:duedesk_mobile/features/client/models/client_tutorial.dart';

void main() {
  group('TutorialVideoSource.resolve', () {
    test('YouTube (watch, youtu.be, embed e shorts) vira player embutido', () {
      for (final url in [
        'https://www.youtube.com/watch?v=abcdefghijk',
        'https://www.youtube.com/watch?feature=share&v=abcdefghijk',
        'https://youtu.be/abcdefghijk',
        'https://www.youtube.com/embed/abcdefghijk',
        'https://www.youtube.com/shorts/abcdefghijk',
      ]) {
        final source = TutorialVideoSource.resolve(url)!;
        expect(source.embedded, isTrue, reason: url);
        expect(source.address, 'https://www.youtube.com/embed/abcdefghijk');
      }
    });

    test('Vimeo vira player embutido', () {
      final source = TutorialVideoSource.resolve('https://vimeo.com/123456789')!;
      expect(source.embedded, isTrue);
      expect(source.address, 'https://player.vimeo.com/video/123456789');
    });

    test('arquivo ou link direto toca no player nativo, com o endereco intacto', () {
      final source = TutorialVideoSource.resolve('  https://dsconnect.duesoft.com.br/rails/active_storage/blobs/proxy/x/aula.mp4 ')!;
      expect(source.embedded, isFalse);
      expect(source.address, 'https://dsconnect.duesoft.com.br/rails/active_storage/blobs/proxy/x/aula.mp4');
    });

    test('sem endereco, nao ha video', () {
      expect(TutorialVideoSource.resolve(null), isNull);
      expect(TutorialVideoSource.resolve('   '), isNull);
    });

    test('o arquivo enviado tem prioridade sobre o link', () {
      final tutorial = ClientTutorial.fromJson({
        'id': 1,
        'title': 'x',
        'video_url': 'https://youtu.be/abcdefghijk',
        'video_file_url': 'https://dsconnect.duesoft.com.br/aula.mp4',
      });
      expect(tutorial.videoSource!.embedded, isFalse);
    });
  });
}
