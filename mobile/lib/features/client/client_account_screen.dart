import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'providers/client_providers.dart';

// Palavra que a pessoa precisa digitar para liberar a exclusao. Um toque sem
// querer nao digita isto.
const _confirmationWord = 'EXCLUIR';

// "Minha conta": onde mora a exclusao da conta. Fica fora do menu de tres
// pontos - la ela ficava a um toque de "Sair", e cliente perdia os dados sem
// querer. Continua dentro do app (as lojas exigem que a exclusao seja
// encontravel), so que atras de uma tela propria, no fim, e com confirmacao
// digitada.
class ClientAccountScreen extends ConsumerWidget {
  const ClientAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Minha conta')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Excluir conta',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colors.error),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A exclusão é permanente: seus dados pessoais são removidos e você não conseguirá mais entrar. '
                    'Se só quer sair do app, use "Sair" no menu.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                    ),
                    onPressed: () => _showDeleteAccountDialog(context, ref),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Excluir minha conta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    String? errorMsg;
    bool isDeleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final confirmed = confirmationController.text.trim().toUpperCase() == _confirmationWord;

          return AlertDialog(
            title: const Text('Excluir minha conta'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta ação é permanente e não pode ser desfeita. Seus dados pessoais serão removidos e você não conseguirá mais fazer login.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmationController,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Digite $_confirmationWord para confirmar',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirme sua senha',
                      errorText: errorMsg,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: (!confirmed || isDeleting)
                    ? null
                    : () async {
                        final password = passwordController.text;
                        if (password.isEmpty) {
                          setDialogState(() => errorMsg = 'Informe sua senha.');
                          return;
                        }
                        setDialogState(() {
                          isDeleting = true;
                          errorMsg = null;
                        });
                        try {
                          await ref.read(clientRepositoryProvider).deleteAccount(password);
                          // Fecha o dialogo e esta tela antes de deslogar: a
                          // troca para o login nao leva rotas empilhadas junto.
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                          await ref.read(sessionProvider.notifier).logout();
                        } catch (_) {
                          setDialogState(() {
                            isDeleting = false;
                            errorMsg = 'Senha incorreta. Verifique e tente novamente.';
                          });
                        }
                      },
                child: const Text('Excluir minha conta'),
              ),
            ],
          );
        },
      ),
    );
    passwordController.dispose();
    confirmationController.dispose();
  }
}
