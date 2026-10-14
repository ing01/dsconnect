import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import 'models/chat_message.dart';
import 'providers/chat_notifier.dart';

class ClientChatScreen extends ConsumerStatefulWidget {
  const ClientChatScreen({super.key});

  @override
  ConsumerState<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends ConsumerState<ClientChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  bool _isRecording = false;

  // Marcar como "vista" ao abrir o chat fica a cargo de quem troca de aba
  // (ClientHomeShell) - esta tela e' montada uma unica vez pelo `IndexedStack`
  // junto com as outras abas, entao `initState` aqui rodaria so' na abertura
  // do app, nao a cada troca de aba de verdade.

  @override
  void dispose() {
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
        error: (error, _) => const Center(child: Text('Não foi possível abrir o chat.')),
        data: (state) {
          final messages = state.session?.messages ?? const [];
          return Column(
            children: [
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

class _ChatAttachmentView extends StatelessWidget {
  const _ChatAttachmentView({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.dataUrl.isEmpty) return const SizedBox.shrink();

    if (attachment.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            attachment.dataUrl,
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

    return const SizedBox.shrink();
  }
}

class _AudioAttachmentPlayer extends StatefulWidget {
  const _AudioAttachmentPlayer({required this.url});

  final String url;

  @override
  State<_AudioAttachmentPlayer> createState() => _AudioAttachmentPlayerState();
}

class _AudioAttachmentPlayerState extends State<_AudioAttachmentPlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

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
      await _player.play(UrlSource(widget.url));
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
