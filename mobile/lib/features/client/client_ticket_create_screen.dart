import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client_ticket_detail_screen.dart';
import 'providers/client_providers.dart';

class ClientTicketCreateScreen extends ConsumerStatefulWidget {
  const ClientTicketCreateScreen({super.key});

  @override
  ConsumerState<ClientTicketCreateScreen> createState() => _ClientTicketCreateScreenState();
}

class _ClientTicketCreateScreenState extends ConsumerState<ClientTicketCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categoryId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openAiDraftSheet() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AiDraftSheet(),
    );
    if (text == null || text.trim().isEmpty) return;
    if (!mounted) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final draft = await ref.read(clientRepositoryProvider).generateDraft(text.trim());
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        _titleController.text = draft.title;
        _descriptionController.text = draft.description;
        if (draft.categoryId != null) _categoryId = draft.categoryId;
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o rascunho. Preencha manualmente.')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      if (_categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha uma categoria.')));
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final detail = await ref.read(clientRepositoryProvider).createTicket(
            categoryId: _categoryId!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
          );
      ref.invalidate(clientTicketsProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: detail.ticket.id)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o chamado. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(ticketCategoriesProvider);
    final aiEnabledAsync = ref.watch(aiDraftEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Abrir chamado')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (aiEnabledAsync.value == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  onPressed: _openAiDraftSheet,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Abrir com IA (descreva o problema)'),
                ),
              ),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Não foi possível carregar as categorias.'),
              data: (categories) => DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final category in categories) DropdownMenuItem(value: category.id, child: Text(category.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Assunto'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Informe o assunto' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição do problema'),
              maxLines: 6,
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Descreva o problema' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Abrir chamado'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiDraftSheet extends StatefulWidget {
  const _AiDraftSheet();

  @override
  State<_AiDraftSheet> createState() => _AiDraftSheetState();
}

class _AiDraftSheetState extends State<_AiDraftSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Descreva o problema', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('A IA sugere a categoria, o assunto e a descrição - você revisa antes de confirmar.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ex.: Não consigo emitir nota fiscal...', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Gerar rascunho'),
          ),
        ],
      ),
    );
  }
}
