import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'push_notification_service.dart';

// Item do menu de três pontinhos: "Ativar notificações" quando o aparelho ainda
// não está recebendo avisos, "Desativar notificações" quando está.
// Le o estado sozinho (provider) a cada vez que o menu abre: antes o valor vinha
// de fora e, na tela do cliente, nunca era lido - o item sempre dizia "Ativar".
class PushMenuTile extends ConsumerWidget {
  const PushMenuTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(pushEnabledProvider).value ?? false;
    return ListTile(
      leading: Icon(enabled ? Icons.notifications_off_outlined : Icons.notifications_active_outlined),
      title: Text(enabled ? 'Desativar notificações' : 'Ativar notificações'),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

// Liga ou desliga as notificações deste aparelho e avisa o resultado.
Future<void> togglePushNotifications(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(pushNotificationServiceProvider);
  final session = ref.read(sessionProvider).value;
  if (session == null) return;

  final wasEnabled = await service.isActive();
  String message;
  if (wasEnabled) {
    await service.disable(session);
    message = 'Notificações desativadas neste aparelho.';
  } else {
    final result = await service.enable(session);
    message = switch (result) {
      PushEnableResult.enabled => 'Notificações ativadas.',
      PushEnableResult.blockedBySystem =>
        'As notificações estão bloqueadas nas configurações do aparelho. Ative-as para o app em Configurações > Notificações e tente de novo.',
      PushEnableResult.failed => 'Não foi possível ativar as notificações agora. Tente novamente.',
    };
  }

  ref.invalidate(pushEnabledProvider);
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
