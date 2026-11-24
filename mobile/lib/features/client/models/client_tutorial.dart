// Um modulo da aba "Tutoriais" (DS Connect, DS Comercial...) e os videos dentro dele - o mesmo que
// a Area do Cliente mostra (Api::V1::Client::TutorialsController).
class TutorialModule {
  const TutorialModule({required this.id, required this.name, this.description, this.logoUrl});

  final int id;
  final String name;
  final String? description;
  final String? logoUrl;

  factory TutorialModule.fromJson(Map<String, dynamic> json) => TutorialModule(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        description: _blankToNull(json['description'] as String?),
        logoUrl: _blankToNull(json['logo_url'] as String?),
      );
}

class ClientTutorial {
  const ClientTutorial({
    required this.id,
    required this.title,
    this.moduleId,
    this.description,
    this.videoUrl,
    this.videoFileUrl,
  });

  final int id;
  final String title;
  // Sem modulo, o video cai no card "Geral".
  final int? moduleId;
  final String? description;
  final String? videoUrl;
  final String? videoFileUrl;

  // O arquivo enviado tem prioridade sobre o link (o servidor nunca guarda os dois).
  String? get videoAddress => videoFileUrl ?? videoUrl;

  // Como o video toca, igual a Area do Cliente (helper/tutorialVideo.js): YouTube e Vimeo viram
  // player embutido; qualquer outro endereco e' tratado como arquivo de video.
  TutorialVideoSource? get videoSource => TutorialVideoSource.resolve(videoAddress);

  factory ClientTutorial.fromJson(Map<String, dynamic> json) => ClientTutorial(
        id: json['id'] as int,
        title: (json['title'] as String?) ?? '',
        moduleId: json['module_id'] as int?,
        description: _blankToNull(json['description'] as String?),
        videoUrl: _blankToNull(json['video_url'] as String?),
        videoFileUrl: _blankToNull(json['video_file_url'] as String?),
      );
}

class TutorialVideoSource {
  const TutorialVideoSource({required this.address, required this.embedded});

  // Endereco a tocar: pagina de embed (YouTube/Vimeo) ou o arquivo em si.
  final String address;
  final bool embedded;

  static final _youtube = RegExp(r'(?:youtube\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/)|youtu\.be/)([\w-]{11})');
  static final _vimeo = RegExp(r'vimeo\.com/(?:video/)?(\d+)');

  static TutorialVideoSource? resolve(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;

    final youtube = _youtube.firstMatch(value);
    if (youtube != null) {
      return TutorialVideoSource(address: 'https://www.youtube.com/embed/${youtube.group(1)}', embedded: true);
    }
    final vimeo = _vimeo.firstMatch(value);
    if (vimeo != null) {
      return TutorialVideoSource(address: 'https://player.vimeo.com/video/${vimeo.group(1)}', embedded: true);
    }
    return TutorialVideoSource(address: value, embedded: false);
  }
}

class TutorialCard {
  const TutorialCard({required this.moduleId, required this.name, required this.count, this.description, this.logoUrl});

  final int? moduleId;
  final String name;
  final String? description;
  final String? logoUrl;
  final int count;
}

class TutorialsResult {
  const TutorialsResult({this.modules = const [], this.tutorials = const []});

  final List<TutorialModule> modules;
  final List<ClientTutorial> tutorials;

  factory TutorialsResult.fromJson(Map<String, dynamic> json) => TutorialsResult(
        modules: (json['modules'] as List<dynamic>? ?? const [])
            .map((entry) => TutorialModule.fromJson(entry as Map<String, dynamic>))
            .toList(),
        tutorials: (json['tutorials'] as List<dynamic>? ?? const [])
            .map((entry) => ClientTutorial.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );

  List<ClientTutorial> tutorialsOf(int? moduleId) =>
      tutorials.where((tutorial) => tutorial.moduleId == moduleId).toList();

  // So modulos com video viram card (um card vazio so confunde). Videos sem modulo vao para o card
  // "Geral" (id nulo) - mas so quando existe ao menos um modulo; sem nenhum modulo cadastrado, a
  // lista de videos aparece direto, sem cards.
  List<TutorialCard> get cards {
    final list = [
      for (final module in modules)
        if (tutorialsOf(module.id).isNotEmpty)
          TutorialCard(
            moduleId: module.id,
            name: module.name,
            description: module.description,
            logoUrl: module.logoUrl,
            count: tutorialsOf(module.id).length,
          ),
    ];
    final loose = tutorialsOf(null).length;
    if (loose > 0 && list.isNotEmpty) {
      list.add(TutorialCard(moduleId: null, name: 'Geral', count: loose));
    }
    return list;
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
