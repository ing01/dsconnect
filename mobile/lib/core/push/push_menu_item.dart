import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'push_notification_service.dart';

// Item do menu de três pontinhos: "Ativar notificações" quando o aparelho ainda
// não está recebendo avisos, "Desativar notificações" quando está.
class PushMenuTile extends StatelessWidget {
  const PushMenuTile({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
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
