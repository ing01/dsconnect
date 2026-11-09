import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/app_theme.dart';
import 'chat_blocked.dart';
import 'client_chat_history_screen.dart';
import 'models/chat_message.dart';
import 'providers/chat_notifier.dart';

// Teto de um arquivo enviado pelo chat. Acima disso o app nem tenta subir: avisa
// na hora, em vez de gastar minutos de upload para o servidor recusar.
const int _maxUploadBytes = 100 * 1024 * 1024;

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).ceil().clamp(1, 1 << 30)} KB';
}

class ClientChatScreen extends ConsumerStatefulWidget {
  const ClientChatScreen({super.key});

  @override
  ConsumerState<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends ConsumerState<ClientChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _pollTimer;

  // Rede de seguranca: se o push e o WebSocket falharem os dois, o chat ainda
  // se atualiza sozinho em poucos segundos. Roda so com o app em primeiro plano.
  static const _pollInterval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_isRecording) return;
      ref.read(clientChatProvider.notifier).refresh();
    });
  }

  // Voltar do segundo plano - inclusive ao abrir o app pela notificacao - e
  // o momento em que o chat mais costuma estar desatualizado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      ref.read(clientChatProvider.notifier).resync();
    } else {
      _pollTimer?.cancel();
    }
  }

  // Marcar como "vista" ao abrir o chat fica a cargo de quem troca de aba
  // (ClientHomeShell) - esta tela e' montada uma unica vez pelo `IndexedStack`
  // junto com as outras abas, entao `initState` aqui rodaria so' na abertura
  // do app, nao a cada troca de aba de verdade.

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(clientChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      await ref.read(clientChatProvider.notifier).send('', attachments: [file]);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível acessar a câmera/galeria. Confira a permissão do app.')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;

      final size = picked.lengthSync() ?? await picked.length();
      if (size != null && size > _maxUploadBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'O arquivo "${picked.name}" tem ${_formatBytes(size)} e passa do limite de '
                '${_formatBytes(_maxUploadBytes)}. Escolha um arquivo menor.',
              ),
            ),
          );
        }
        return;
      }

      await ref.read(clientChatProvider.notifier).send('', attachments: [picked.xFile]);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível acessar o arquivo. Confira a permissão do app.')),
        );
      }
    }
  }

  void _openAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Escolher arquivo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null) return;
      await ref.read(clientChatProvider.notifier).send('', attachments: [XFile(path)], isVoiceMessage: true);
      _scrollToBottom();
      return;
    }

    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de microfone negada.')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/chat_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _isRecording = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gravar áudio.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(clientChatProvider);

    ref.listen(clientChatProvider, (previous, next) {
      final previousCount = previous?.value?.session?.messages.length ?? 0;
      final nextCount = next.value?.session?.messages.length ?? 0;
      if (nextCount > previousCount) _scrollToBottom();
    });

    return Scaffold(
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => chatBlockedMessage(error) != null
            ? _BlockedNotice(message: chatBlockedMessage(error)!)
            : Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível abrir o chat.'),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.invalidate(clientChatProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (state) {
          final messages = state.session?.messages ?? const [];
          return Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ClientChatHistoryScreen()),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Histórico'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.outline,
                    textStyle: const TextStyle(fontSize: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('Mande uma mensagem pra começar a conversa.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) => _ChatBubble(message: messages[index]),
                      ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.fiber_manual_record, size: 14, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 6),
                      const Text('Gravando áudio... toque no microfone pra enviar'),
                    ],
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isRecording ? null : _openAttachmentSheet,
                        icon: const Icon(Icons.attach_file),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !_isRecording,
                          decoration: const InputDecoration(hintText: 'Mensagem...', border: OutlineInputBorder()),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: state.isSending ? null : _toggleRecording,
                        icon: Icon(
                          _isRecording ? Icons.stop_circle : Icons.mic_none,
                          color: _isRecording ? Theme.of(context).colorScheme.error : null,
                        ),
                      ),
                      GradientIconButton(
                        onPressed: (state.isSending || _isRecording) ? null : _send,
                        icon: state.isSending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: message.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: message.fromMe ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.fromMe && message.authorName != null)
              Text(
                message.authorName!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            for (final attachment in message.attachments) _ChatAttachmentView(attachment: attachment),
            if (message.content.isNotEmpty) Text(message.content),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt.toLocal()),
              style: TextStyle(fontSize: 10, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// O servidor so' entrega anexo a quem esta logado: a imagem e o audio vao com o
// token da sessao, igual a qualquer outra chamada do app.
class _ChatAttachmentView extends ConsumerWidget {
  const _ChatAttachmentView({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attachment.dataUrl.isEmpty) return const SizedBox.shrink();
    final token = ref.watch(sessionProvider).value?.apiAccessToken;

    if (attachment.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            attachment.dataUrl,
            headers: token == null ? null : {'api_access_token': token},
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox(
              width: 220,
              height: 120,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      );
    }

    if (attachment.isAudio) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _AudioAttachmentPlayer(url: attachment.dataUrl),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _FileAttachmentTile(attachment: attachment),
    );
  }
}

// Um arquivo que nao e' foto nem audio: icone, nome e tamanho; tocar abre no
// navegador/app do aparelho, que baixa ou mostra conforme o tipo.
class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({required this.attachment});

  final ChatAttachment attachment;

  Future<void> _open(BuildContext context) async {
    final opened = await launchUrl(Uri.parse(attachment.dataUrl), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = attachment.fileSize;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _open(context),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName ?? 'Arquivo',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (size != null) Text(_formatBytes(size), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.download_outlined, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AudioAttachmentPlayer extends ConsumerStatefulWidget {
  const _AudioAttachmentPlayer({required this.url});

  final String url;

  @override
  ConsumerState<_AudioAttachmentPlayer> createState() => _AudioAttachmentPlayerState();
}

class _AudioAttachmentPlayerState extends ConsumerState<_AudioAttachmentPlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  // O player nao aceita cabecalho: o audio e' baixado pelo cliente da API (que ja
  // manda o token) e tocado da memoria. Guardado, para nao baixar a cada play.
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((playerState) {
      if (!mounted) return;
      setState(() => _isPlaying = playerState == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      _bytes ??= await _download();
      if (_bytes == null) return;
      await _player.play(BytesSource(_bytes!));
    }
  }

  Future<Uint8List?> _download() async {
    try {
      final response = await ref.read(apiClientProvider).get<List<int>>(
            widget.url,
            options: Options(responseType: ResponseType.bytes),
          );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } on DioException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _toggle,
          icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32),
        ),
        const SizedBox(width: 6),
        const Text('Mensagem de áudio'),
      ],
    );
  }
}

// Aviso no lugar do chat quando o contato esta bloqueado (ver `chat_blocked.dart`).
class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_in_talk_outlined, size: 36, color: scheme.onErrorContainer),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
