import 'package:dio/dio.dart';

import '../auth/auth_mode.dart';
import '../auth/session_storage.dart';

// Injeta em toda requisição os headers certos pro modo logado no momento:
// colaborador manda os 3 do devise_token_auth (access-token/client/uid),
// cliente manda 1 (api_access_token). Sem sessão ainda (login/sign-in em
// si), não manda nenhum - e tanto faz, essas duas rotas não exigem.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessionStorage);

  final SessionStorage _sessionStorage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final session = await _sessionStorage.read();
    if (session != null) {
      if (session.mode == AuthMode.agent) {
        if (session.accessToken != null) options.headers['access-token'] = session.accessToken;
        if (session.client != null) options.headers['client'] = session.client;
        if (session.uid != null) options.headers['uid'] = session.uid;
      } else if (session.apiAccessToken != null) {
        options.headers['api_access_token'] = session.apiAccessToken;
      }
    }
    handler.next(options);
  }

  // O devise_token_auth pode devolver um token NOVO a cada resposta
  // (rotação) - sem guardar o mais recente, a próxima requisição usaria um
  // token velho e cairia em 401. Este servidor não gira a cada requisição
  // hoje, mas guardar aqui deixa o app correto se isso mudar.
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final newAccessToken = response.headers.value('access-token');
    if (newAccessToken != null && newAccessToken.isNotEmpty) {
      final session = await _sessionStorage.read();
      if (session != null && session.mode == AuthMode.agent) {
        await _sessionStorage.save(session.copyWith(
          accessToken: newAccessToken,
          client: response.headers.value('client'),
          uid: response.headers.value('uid'),
        ));
      }
    }
    handler.next(response);
  }
}
