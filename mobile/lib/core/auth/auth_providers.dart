import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../push/push_notification_service.dart';
import 'auth_repository.dart';
import 'biometric_lock.dart';
import 'session.dart';
import 'session_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());

final apiClientProvider = Provider<Dio>((ref) {
  return ApiClient(ref.watch(sessionStorageProvider)).dio;
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(sessionStorageProvider));
});

// Estado de sessão do app inteiro: `null` é deslogado, uma `Session` é
// logado (talvez ainda precisando escolher a conta - ver
// `Session.needsAccountSelection`). Toda tela que depende de estar
// logado/deslogado observa este provider em vez de ter sua própria lógica.
class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final session = await ref.read(authRepositoryProvider).restoreSession();
    _maybeRegisterPush(session);
    return session;
  }

  // So registra quando ha sessao de verdade pronta pra uso (nao precisando
  // mais escolher conta) - registrar cedo demais faria o colaborador com
  // varias contas aparecer inscrito numa conta errada (a que o app ainda
  // nem confirmou qual e).
  void _maybeRegisterPush(Session? session) {
    if (session == null || session.needsAccountSelection) return;
    ref.read(pushNotificationServiceProvider).registerForSession(session);
  }

  // Propositalmente NÃO põe `state = AsyncLoading()` no começo: isso faria o
  // `_RootGate` trocar a tela de login inteira por uma tela de carregamento
  // genérica enquanto a requisição está em andamento, destruindo o widget da
  // tela de login - aí quando o erro chegasse, não haveria mais tela pra
  // mostrar a mensagem (e o app quebrava tentando atualizar um widget morto).
  // A própria tela de login já mostra seu loading local no botão.
  Future<void> login({required String email, required String password, bool enableBiometric = false}) async {
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email: email, password: password),
    );
    // Só atualiza o estado global em caso de sucesso - um erro de login fica
    // só na tela (via exceção relançada abaixo), não deve derrubar uma sessão
    // válida que porventura já existisse.
    if (result.hasValue) {
      // Antes de publicar a sessão: o gate não pode ver sessão + trava
      // antiga e mostrar a tela de biometria logo após um login válido.
      final biometric = ref.read(biometricLockProvider.notifier);
      if (enableBiometric) {
        await biometric.enable(email, password);
      } else {
        biometric.markUnlocked();
      }
      state = result;
      _maybeRegisterPush(result.value);
    }
    // `AsyncValue.guard` só guarda o erro no resultado - não relança. Sem
    // isso, a tela de login nunca saberia que algo deu errado.
    if (result.hasError) Error.throwWithStackTrace(result.error!, result.stackTrace!);
  }

  // Entra com a credencial guardada, depois de uma leitura biométrica. Se o
  // servidor recusar a senha (trocada em outro lugar), apaga a credencial
  // pra o usuário voltar ao login normal e reativar.
  Future<void> loginWithBiometrics() async {
    final biometric = ref.read(biometricLockProvider.notifier);
    final credentials = await biometric.credentials();
    if (credentials == null) throw AuthException('Biometria não está ativada neste aparelho.');
    if (!await biometric.authenticate('Confirme sua identidade para entrar')) {
      throw AuthException('Não foi possível confirmar sua identidade.');
    }
    try {
      await login(email: credentials.email, password: credentials.password);
    } on AuthException catch (error) {
      if (error.invalidCredentials) {
        await biometric.disable();
        throw AuthException('Sua senha mudou. Entre com a nova senha para ativar a biometria de novo.');
      }
      rethrow;
    }
  }

  Future<void> selectAccount(int accountId) async {
    await ref.read(authRepositoryProvider).selectAccount(accountId);
    final session = await AsyncValue.guard(() => ref.read(authRepositoryProvider).restoreSession());
    state = session;
    _maybeRegisterPush(session.value);
  }

  Future<void> logout() async {
    // Antes de apagar a sessao: e' ela que autentica a desinscricao do push.
    final session = state.value;
    if (session != null && !session.needsAccountSelection) {
      await ref.read(pushNotificationServiceProvider).unregisterForSession(session);
    }
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
