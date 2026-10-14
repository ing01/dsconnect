import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  // Marcar como "vista" ao abrir o chat fica a cargo de quem troca de aba
  // (ClientHomeShell) - esta tela e' montada uma unica vez pelo `IndexedStack`
  // junto com as outras abas, entao `initState` aqui rodaria so' na abertura
  // do app, nao a cada troca de aba de verdade.

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(hintText: 'Mensagem...', border: OutlineInputBorder()),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GradientIconButton(
                        onPressed: state.isSending ? null : _send,
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
            Text(message.content),
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
