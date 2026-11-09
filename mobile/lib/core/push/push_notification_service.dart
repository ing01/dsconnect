import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_mode.dart';
import '../auth/session.dart';
import 'push_filter.dart';

const _androidChannel = AndroidNotificationChannel(
  'default_channel',
  'Notificações',
  description: 'Avisos de chamados e mensagens novas',
  importance: Importance.high,
);

// Precisa ser de nivel superior (nao de instancia) e marcada assim - e'
// exigencia do firebase_messaging pra rodar com o app fechado/em 2o plano.
// So existir ja basta: o FCM mostra a notificacao do sistema sozinho a
// partir do bloco `notification` do payload (ver `fcm_notification` no
// servidor, Notification::PushNotificationService) quando o app nao esta em
// primeiro plano - so o caso de app aberto (`onMessage`) precisa de codigo
// nosso pra aparecer (ver `_showForegroundNotification`).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

// Registra o token FCM deste aparelho no servidor certo pro modo logado
// (colaborador ou cliente - ver NotificationSubscriptionsController e
// Api::V1::Client::PushSubscriptionsController) e mostra a notificacao na
// tela quando o app esta aberto (o sistema so faz isso sozinho em 2o plano).
// Resultado de "Ativar notificações" pelo menu.
enum PushEnableResult { enabled, blockedBySystem, failed }

class PushNotificationService {
  PushNotificationService(this._dio);

  final Dio _dio;
  static const _deviceIdKey = 'push_device_id';
  // A pessoa desligou as notificacoes pelo menu: o app nao registra o aparelho de
  // novo (nem ao abrir, nem ao entrar) ate' ela ligar outra vez.
  static const _disabledKey = 'push_disabled_by_user';
  final _secureStorage = const FlutterSecureStorage();
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  // Sair da conta cancela: um token novo gerado depois nao pode ser registrado
  // com a sessao que acabou de sair.
  StreamSubscription<String>? _tokenRefreshSubscription;

  // A tela do cliente (bolinha vermelha no icone do Chat) escuta isto pra
  // saber que chegou algo novo enquanto o app esta aberto, sem precisar sair
  // e voltar da tela pra recarregar a lista de notificacoes.
  final _messageController = StreamController<void>.broadcast();
  Stream<void> get onMessageReceived => _messageController.stream;

  // Ligado pela tela do cliente enquanto a aba do Chat esta aberta: nesse caso
  // o aviso de CONVERSA nao e' mostrado (ela ja esta na tela), e o de ticket
  // continua aparecendo (ver `shouldShowForegroundPush`).
  bool chatTabOpen = false;

  // So estes dois estados contam como "o sistema permite avisos" - qualquer
  // outra coisa (negado, ou negado sem dialogo nenhum - ver `_isAuthorized`)
  // precisa ser tratada como bloqueado, nunca como sucesso.
  bool _isAuthorized(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  // Notificacoes "ativas": a pessoa nao as desligou e o sistema permite avisos.
  Future<bool> isActive() async {
    try {
      if (await _secureStorage.read(key: _disabledKey) == 'true') return false;
      return _isAuthorized(await FirebaseMessaging.instance.getNotificationSettings());
    } catch (error) {
      debugPrint('Falha ao ler o estado das notificacoes: $error');
      return false;
    }
  }

  Future<PushEnableResult> enable(Session session) async {
    try {
      await _secureStorage.delete(key: _disabledKey);
      await _ensureInitialized();
      final settings = await FirebaseMessaging.instance.requestPermission();
      // Depois de uma negacao anterior, o Android pode nem reabrir a telinha
      // (so decide sozinho) - `denied` nao e' o unico jeito disso aparecer,
      // entao so aceita como sucesso o que for de fato autorizado.
      if (!_isAuthorized(settings)) return PushEnableResult.blockedBySystem;

      await registerForSession(session);
      return PushEnableResult.enabled;
    } catch (error) {
      debugPrint('Falha ao ativar o push: $error');
      return PushEnableResult.failed;
    }
  }

  // So desinscreve no servidor - mantem o token FCM vivo. Apagar o token
  // aqui (como faz `unregisterForSession`, pensado pra logout) e gerar um
  // novo pouco depois ao religar e' propenso a voltar o token antigo/vazio;
  // sem a sessao sendo encerrada, nao ha motivo pra arriscar isso.
  Future<void> disable(Session session) async {
    await _secureStorage.write(key: _disabledKey, value: 'true');
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _unsubscribeFromServer(session);
  }

  Future<void> registerForSession(Session session) async {
    try {
      if (await _secureStorage.read(key: _disabledKey) == 'true') return;
      await _ensureInitialized();

      final settings = await FirebaseMessaging.instance.requestPermission();
      if (!_isAuthorized(settings)) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(session, token);

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) => _sendToken(session, newToken));
    } catch (error) {
      // Falha ao registrar push nao pode derrubar o app - o resto continua
      // funcionando normalmente, so sem notificacao.
      debugPrint('Falha ao registrar push: $error');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    _messageController.add(null);

    if (!shouldShowForegroundPush(message.data, chatTabOpen: chatTabOpen)) return;

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // Um id estavel por aparelho/instalacao - o token FCM em si roda sozinho
  // de tempos em tempos, e o servidor usa esse id (nao o token) pra saber
  // que e' "o mesmo aparelho" e so atualizar a inscricao, nao duplicar.
  Future<String> _deviceId() async {
    final existing = await _secureStorage.read(key: _deviceIdKey);
    if (existing != null) return existing;

    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.write(key: _deviceIdKey, value: id);
    return id;
  }

  // Sair da conta: este aparelho deixa de receber os avisos dela. Desinscreve
  // no servidor (precisa rodar ANTES de apagar a sessao, que autentica a
  // chamada) e invalida o token FCM - assim, mesmo que o servidor nao responda
  // (sem rede, conta apagada), o token velho nao entrega mais nada; o proximo
  // login gera um novo e registra de novo (`registerForSession`).
  Future<void> unregisterForSession(Session session) async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _unsubscribeFromServer(session);

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Falha ao invalidar o token de push: $error');
    }
  }

  Future<void> _unsubscribeFromServer(Session session) async {
    try {
      final deviceId = await _deviceId();
      if (session.mode == AuthMode.client) {
        await _dio.delete<void>('/api/v1/client/push_subscription', queryParameters: {'device_id': deviceId});
      } else if (session.selectedAccountId != null) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _dio.delete<void>(
            '/api/v1/accounts/${session.selectedAccountId}/notification_subscriptions',
            queryParameters: {'push_token': token},
          );
        }
      }
    } catch (error) {
      debugPrint('Falha ao desinscrever o push no servidor: $error');
    }
  }

  Future<void> _sendToken(Session session, String token) async {
    final deviceId = await _deviceId();
    final attributes = {'device_id': deviceId, 'push_token': token};

    try {
      if (session.mode == AuthMode.client) {
        await _dio.post('/api/v1/client/push_subscription', data: {
          'subscription_type': 'fcm',
          'subscription_attributes': attributes,
        });
        return;
      }

      final accountId = session.selectedAccountId;
      if (accountId == null) return;

      await _dio.post('/api/v1/accounts/$accountId/notification_subscriptions', data: {
        'notification_subscription': {
          'subscription_type': 'fcm',
          'subscription_attributes': attributes,
        },
      });
    } catch (error) {
      debugPrint('Falha ao enviar token de push ao servidor: $error');
    }
  }
}
