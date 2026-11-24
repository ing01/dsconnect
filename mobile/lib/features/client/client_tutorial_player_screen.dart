import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/auth/auth_providers.dart';
import 'models/client_tutorial.dart';

// Toca o video do tutorial DENTRO do app, igual a Area do Cliente na web:
// - YouTube/Vimeo: player embutido (pagina de embed numa WebView);
// - arquivo enviado ou link direto: player nativo, com os controles de sempre.
// O arquivo enviado so' e' entregue a quem esta logado, entao o pedido leva o token da sessao.
class ClientTutorialPlayerScreen extends ConsumerWidget {
  const ClientTutorialPlayerScreen({super.key, required this.tutorial});

  final ClientTutorial tutorial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = tutorial.videoSource;
    final token = ref.watch(sessionProvider).value?.apiAccessToken;

    return Scaffold(
      appBar: AppBar(title: Text(tutorial.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          children: [
            if (source == null)
              const Padding(padding: EdgeInsets.all(24), child: Text('Este vídeo não está disponível.'))
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: source.embedded
                    ? _EmbeddedPlayer(address: source.address)
                    : _FilePlayer(address: source.address, token: token),
              ),
            if (tutorial.description != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(tutorial.description!)),
          ],
        ),
      ),
    );
  }
}

class _FilePlayer extends StatefulWidget {
  const _FilePlayer({required this.address, required this.token});

  final String address;
  final String? token;

  @override
  State<_FilePlayer> createState() => _FilePlayerState();
}

class _FilePlayerState extends State<_FilePlayer> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final uri = Uri.tryParse(widget.address);
    if (uri == null) {
      setState(() => _failed = true);
      return;
    }
    final video = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: widget.token == null ? const {} : {'api_access_token': widget.token!},
    );
    _video = video;
    try {
      await video.initialize();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _chewie = ChewieController(
        videoPlayerController: video,
        autoPlay: true,
        aspectRatio: video.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
      );
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('Não foi possível carregar o vídeo.', style: TextStyle(color: Colors.white))),
      );
    }
    final chewie = _chewie;
    if (chewie == null) {
      return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    }
    return ColoredBox(color: Colors.black, child: Chewie(controller: chewie));
  }
}

class _EmbeddedPlayer extends StatefulWidget {
  const _EmbeddedPlayer({required this.address});

  final String address;

  @override
  State<_EmbeddedPlayer> createState() => _EmbeddedPlayerState();
}

class _EmbeddedPlayerState extends State<_EmbeddedPlayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // O YouTube recusa o embed sem um "Referer" que identifique quem incorpora: o HTML
    // proprio com baseUrl resolve, e a navegacao fica presa ao player (nada de sair do video).
    final html = '<html><body style="margin:0;background:#000">'
        '<iframe src="${widget.address}" style="border:0;position:absolute;inset:0;width:100%;height:100%" '
        'allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>'
        '</body></html>';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(html, baseUrl: 'https://dsconnect.duesoft.com.br');
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
