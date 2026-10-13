import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/session.dart';

// Só aparece quando o colaborador logado pertence a mais de uma conta (ver
// Session.needsAccountSelection) - a maioria nunca vê esta tela.
class AccountPickerScreen extends ConsumerWidget {
  const AccountPickerScreen({super.key, required this.accounts});

  final List<AgentAccount> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha a conta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final account = accounts[index];
          return Card(
            child: ListTile(
              title: Text(account.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ref.read(sessionProvider.notifier).selectAccount(account.id),
            ),
          );
        },
      ),
    );
  }
}
