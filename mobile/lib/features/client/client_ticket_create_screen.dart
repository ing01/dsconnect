import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bordered_card.dart';
import 'client_ticket_detail_screen.dart';
import 'models/ticket_category.dart';
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
  final List<XFile> _attachments = [];
  String? _attachmentError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      setState(() {
        _attachments.add(file);
        _attachmentError = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível acessar a câmera/galeria. Confira a permissão do app.')),
        );
      }
    }
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
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    }
  }

  bool _requiresAttachment(List<TicketCategory> categories) {
    return categories.where((c) => c.id == _categoryId).firstOrNull?.requireAttachment == true;
  }

  Future<void> _submit(List<TicketCategory> categories) async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      if (_categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha uma categoria.')));
      }
      return;
    }

    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    if (category?.requireAttachment == true && _attachments.isEmpty) {
      setState(() => _attachmentError = 'Esta categoria exige pelo menos um anexo (foto/print).');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final detail = await ref.read(clientRepositoryProvider).createTicket(
            categoryId: _categoryId!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            attachments: _attachments,
          );
      ref.invalidate(clientTicketsProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: detail.ticket.id)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
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
              error: (error, _) => Text(
                'Não foi possível carregar as categorias.\n${describeApiError(error)}',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
              data: (categories) => DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                items: [
                  for (final category in categories) DropdownMenuItem(value: category.id, child: Text(category.name)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Assunto', border: OutlineInputBorder()),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Informe o assunto' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição do problema', border: OutlineInputBorder()),
              maxLines: 6,
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Descreva o problema' : null,
            ),
            const SizedBox(height: 16),
            BorderedCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Anexos',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_requiresAttachment(categoriesAsync.value ?? const []))
                        Text(
                          ' *',
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final file in _attachments)
                        _AttachmentThumbnail(
                          file: file,
                          onRemove: () => setState(() => _attachments.remove(file)),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Tirar foto'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Galeria'),
                      ),
                    ],
                  ),
                  if (_attachmentError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_attachmentError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              onPressed: _isSubmitting ? null : () => _submit(categoriesAsync.value ?? const []),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Abrir chamado'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(file.path), width: 64, height: 64, fit: BoxFit.cover),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: onRemove,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Theme.of(context).colorScheme.error,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
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
