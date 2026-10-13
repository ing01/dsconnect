import 'package:dio/dio.dart';

import 'auth_mode.dart';
import 'session.dart';
import 'session_storage.dart';

// Erro pensado pra aparecer direto na tela de login, em português - as
// outras exceções (timeout, servidor fora do ar) o chamador trata com uma
// mensagem genérica.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

// Um só formulário de login: tenta autenticar como colaborador primeiro
// (`POST /auth/sign_in`); se a credencial não bater lá (401 - não é um erro
// de rede nem de servidor), tenta como cliente final
// (`POST /api/v1/client/session`). Decisão da Ingrid: o app não pergunta
// "você é colaborador ou cliente?" antes de tentar.
class AuthRepository {
  AuthRepository(this._dio, this._sessionStorage);

  final Dio _dio;
  final SessionStorage _sessionStorage;

  Future<Session> login({required String email, required String password}) async {
    DioException? agentError;
    try {
      return await _loginAsAgent(email: email, password: password);
    } on DioException catch (error) {
      agentError = error;
      // So' vale tentar como cliente quando o colaborador deu "credencial
      // errada" (401) de verdade - qualquer outro erro (fora do ar, servidor
      // com problema, etc.) e' o diagnostico de verdade, e cai direto no
      // catch abaixo em vez de ser escondido atras de uma tentativa de
      // cliente que provavelmente tambem vai falhar (mascarando o erro real
      // atras de "senha incorreta", que pode nem ser o problema).
      if (error.response?.statusCode != 401) throw AuthException(_describeError(error));
    }

    try {
      return await _loginAsClient(email: email, password: password);
    } on DioException catch (error) {
      // Os DOIS lados recusaram com "credencial errada" - agora sim e'
      // seguro dizer que e' senha errada.
      if (agentError.response?.statusCode == 401 && error.response?.statusCode == 401) {
        throw AuthException('E-mail ou senha incorretos.');
      }
      throw AuthException(_describeError(error));
    }
  }

  // Mensagem com o que o servidor respondeu de verdade - usada so' quando o
  // caso NAO e' o simples "e-mail ou senha incorretos" de sempre, pra dar um
  // diagnostico de verdade em vez de uma mensagem generica demais pra agir.
  String _describeError(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) return 'Não foi possível conectar ao servidor (${error.message}).';

    final body = error.response?.data;
    return 'O servidor respondeu com erro $status: $body';
  }

  Future<Session> _loginAsAgent({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/sign_in',
      data: {'email': email, 'password': password},
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    final accounts = (data['accounts'] as List<dynamic>? ?? const [])
        .map((entry) => AgentAccount.fromJson(entry as Map<String, dynamic>))
        .toList();

    var session = Session(
      mode: AuthMode.agent,
      accessToken: response.headers.value('access-token'),
      client: response.headers.value('client'),
      uid: response.headers.value('uid'),
      userId: data['id'] as int?,
      pubsubToken: data['pubsub_token'] as String?,
      accounts: accounts,
    );

    // Só uma conta: não faz sentido perguntar, já entra direto nela.
    if (accounts.length == 1) {
      session = session.copyWith(selectedAccountId: accounts.first.id);
    }

    await _sessionStorage.save(session);
    return session;
  }

  Future<Session> _loginAsClient({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/client/session',
      data: {'email': email, 'password': password},
    );

    final contact = response.data!['contact'] as Map<String, dynamic>?;
    final session = Session(
      mode: AuthMode.client,
      apiAccessToken: response.data!['api_access_token'] as String?,
      contactId: contact?['id'] as int?,
    );

    await _sessionStorage.save(session);
    return session;
  }

  Future<void> selectAccount(int accountId) async {
    final session = await _sessionStorage.read();
    if (session == null) return;
    await _sessionStorage.save(session.copyWith(selectedAccountId: accountId));
  }

  Future<Session?> restoreSession() => _sessionStorage.read();

  Future<void> logout() => _sessionStorage.clear();
}
