import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';

// "Esqueci minha senha": pede o link de redefinição por e-mail. Serve ao
// colaborador e ao cliente - o servidor decide qual dos dois é pelo e-mail.
Future<void> showForgotPasswordSheet(BuildContext context, {String initialEmail = ''}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ForgotPasswordSheet(initialEmail: initialEmail),
  );
}

class ForgotPasswordSheet extends ConsumerStatefulWidget {
  const ForgotPasswordSheet({this.initialEmail = '', super.key});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // O e-mail que a pessoa já digitou no login vem junto: evita digitar de novo.
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Não foi possível enviar o e-mail agora. Tente novamente em instantes.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // O teclado sobe por cima de uma sheet de altura livre: sem este espaço ele
    // cobriria o campo e o botão.
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboardHeight),
        child: _sent ? _buildSent(context) : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Esqueci minha senha',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Informe o e-mail da sua conta. Enviaremos um link para você criar uma nova senha.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Informe o e-mail';
              if (!email.contains('@')) return 'Informe um e-mail válido';
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          GradientButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enviar link'),
          ),
        ],
      ),
    );
  }

  // O servidor responde igual exista o e-mail ou não (para a tela não servir
  // de verificador de cadastro), então o texto também não afirma que enviou.
  Widget _buildSent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 44, color: Color(0xFF2781F6)),
        const SizedBox(height: 16),
        const Text(
          'Confira seu e-mail',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Se o e-mail estiver cadastrado, enviamos um link para criar uma nova senha. '
          'Abra a mensagem e toque no link - a nova senha é definida no navegador. '
          'Depois, volte ao app e entre. Não chegou? Veja a caixa de spam.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
