import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duedesk_mobile/core/api/auth_interceptor.dart';
import 'package:duedesk_mobile/core/auth/auth_mode.dart';
import 'package:duedesk_mobile/core/auth/session.dart';
import 'package:duedesk_mobile/core/auth/session_storage.dart';

class _MemoryStorage extends SessionStorage {
  _MemoryStorage(this.session);

  Session? session;

  @override
  Future<void> save(Session value) async => session = value;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> clear() async => session = null;
}

// Responde sempre 401 com o corpo escolhido, sem rede.
class _Answers401 implements HttpClientAdapter {
  _Answers401(this.body, {this.whileWaiting});

  final Map<String, dynamic> body;
  // Algo que acontece enquanto o servidor ainda nao respondeu (ex.: a pessoa entrou de novo).
  final void Function()? whileWaiting;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    whileWaiting?.call();
    return ResponseBody.fromString(jsonEncode(body), 401, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const clientSession = Session(mode: AuthMode.client, apiAccessToken: 'token-atual', contactId: 1);

  Future<({Dio dio, _MemoryStorage storage, List<int> expired})> setup(
    Map<String, dynamic> body,
    Session? session, {
    void Function(_MemoryStorage storage)? whileWaiting,
  }) async {
    final storage = _MemoryStorage(session);
    final expired = <int>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://teste.local'))
      ..httpClientAdapter = _Answers401(body, whileWaiting: whileWaiting == null ? null : () => whileWaiting(storage))
      ..interceptors.add(AuthInterceptor(storage, onSessionExpired: () => expired.add(1)));
    return (dio: dio, storage: storage, expired: expired);
  }

  test('401 de sessao invalida apaga a sessao do cliente e avisa', () async {
    final env = await setup({'error': 'x', 'code': 'session_invalid'}, clientSession);

    await expectLater(env.dio.get('/api/v1/client/categories'), throwsA(isA<DioException>()));

    expect(env.storage.session, isNull);
    expect(env.expired, hasLength(1));
  });

  test('outro 401 do cliente (ex.: senha errada ao excluir a conta) nao derruba a sessao', () async {
    final env = await setup({'error': 'Senha incorreta.'}, clientSession);

    await expectLater(env.dio.delete('/api/v1/client/account'), throwsA(isA<DioException>()));

    expect(env.storage.session, isNotNull);
    expect(env.expired, isEmpty);
  });

  test('sem sessao guardada (login) nada acontece', () async {
    final env = await setup({'error': 'x', 'code': 'session_invalid'}, null);

    await expectLater(env.dio.post('/api/v1/client/session'), throwsA(isA<DioException>()));

    expect(env.expired, isEmpty);
  });

  test('resposta de um token antigo nao derruba a sessao nova', () async {
    final env = await setup(
      {'error': 'x', 'code': 'session_invalid'},
      clientSession,
      // A pessoa entrou de novo enquanto a chamada antiga ainda estava no ar.
      whileWaiting: (storage) => storage.session = const Session(mode: AuthMode.client, apiAccessToken: 'token-novo', contactId: 1),
    );

    await expectLater(env.dio.get('/api/v1/client/categories'), throwsA(isA<DioException>()));

    expect(env.storage.session?.apiAccessToken, 'token-novo');
    expect(env.expired, isEmpty);
  });

  test('colaborador nao e afetado', () async {
    final env = await setup(
      {'error': 'x', 'code': 'session_invalid'},
      const Session(mode: AuthMode.agent, accessToken: 'a', client: 'c', uid: 'u'),
    );

    await expectLater(env.dio.get('/api/v1/profile'), throwsA(isA<DioException>()));

    expect(env.storage.session, isNotNull);
    expect(env.expired, isEmpty);
  });
}
