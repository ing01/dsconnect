import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duedesk_mobile/core/auth/auth_providers.dart';
import 'package:duedesk_mobile/core/auth/session.dart';
import 'package:duedesk_mobile/core/auth/biometric_lock.dart';
import 'package:duedesk_mobile/core/push/push_notification_service.dart';
import 'package:duedesk_mobile/features/client/client_home_shell.dart';
import 'package:duedesk_mobile/features/client/client_ticket_detail_screen.dart';
import 'package:duedesk_mobile/features/client/models/client_ticket_detail.dart';
import 'package:duedesk_mobile/features/client/models/client_notification.dart';
import 'package:duedesk_mobile/features/client/providers/client_providers.dart';

class _FakeSession extends SessionNotifier {
  @override
  Future<Session?> build() async => null;
}

class _FakeBiometric extends BiometricLockNotifier {
  @override
  Future<BiometricState> build() async => const BiometricState(enabled: false, locked: false);
}

class _FakeDismissed extends DismissedNotificationsNotifier {
  @override
  Future<Set<String>> build() async => <String>{};

  @override
  Future<void> dismiss(String id) async {
    state = AsyncData({...?state.value, id});
  }
}

class _NeverLoadingDetail extends ClientTicketDetailNotifier {
  _NeverLoadingDetail(super.ticketId);

  @override
  Future<ClientTicketDetail> build() => Completer<ClientTicketDetail>().future;
}

void main() {
  // O aviso "A equipe respondeu no chamado #..." tem a acao "Ver", que tem de
  // abrir o chamado - o cliente reclamou que nao abria.
  testWidgets('"Ver" na faixa de resposta abre o chamado', (tester) async {
    // Tela de celular: com a janela padrao do teste (800x600) a entrada estoura.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // A fonte de teste (Ahem) e' mais larga que a real e estoura uma linha da tela
    // de entrada - problema do ambiente de teste, nao do app.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    final items = <ClientNotification>[];

    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_FakeSession.new),
        biometricLockProvider.overrideWith(_FakeBiometric.new),
        dismissedNotificationsProvider.overrideWith(_FakeDismissed.new),
        pushNotificationServiceProvider.overrideWithValue(PushNotificationService(Dio())),
        clientNotificationsProvider.overrideWith((ref) async => List.of(items)),
        clientTicketDetailProvider.overrideWith(() => _NeverLoadingDetail(0)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ClientHomeShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Nova resposta chega depois da primeira carga.
    items.add(
      ClientNotification(
        id: 'communication_1',
        type: 'ticket',
        ticketId: 49001,
        ticketDisplayId: 34831,
        ticketTitle: 'Atualizacao',
        preview: 'Ola Guilherme, o ticket foi movido',
        authorName: null,
        createdAt: DateTime.now(),
      ),
    );
    container.invalidate(clientNotificationsProvider);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('A equipe respondeu no chamado #34831'), findsOneWidget);

    await tester.tap(find.text('Ver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ClientTicketDetailScreen), findsOneWidget);
  });
}
