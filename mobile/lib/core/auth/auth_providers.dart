import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'auth_repository.dart';
import 'session.dart';
import 'session_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());

final apiClientProvider = Provider<Dio>((ref) {
  return ApiClient(ref.watch(sessionStorageProvider)).dio;
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
  Future<Session?> build() => ref.read(authRepositoryProvider).restoreSession();

  // Propositalmente NÃO põe `state = AsyncLoading()` no começo: isso faria o
  // `_RootGate` trocar a tela de login inteira por uma tela de carregamento
  // genérica enquanto a requisição está em andamento, destruindo o widget da
  // tela de login - aí quando o erro chegasse, não haveria mais tela pra
  // mostrar a mensagem (e o app quebrava tentando atualizar um widget morto).
  // A própria tela de login já mostra seu loading local no botão.
  Future<void> login({required String email, required String password}) async {
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email: email, password: password),
    );
    // Só atualiza o estado global em caso de sucesso - um erro de login fica
    // só na tela (via exceção relançada abaixo), não deve derrubar uma sessão
    // válida que porventura já existisse.
    if (result.hasValue) state = result;
    // `AsyncValue.guard` só guarda o erro no resultado - não relança. Sem
    // isso, a tela de login nunca saberia que algo deu errado.
    if (result.hasError) Error.throwWithStackTrace(result.error!, result.stackTrace!);
  }

  Future<void> selectAccount(int accountId) async {
    await ref.read(authRepositoryProvider).selectAccount(accountId);
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).restoreSession());
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
