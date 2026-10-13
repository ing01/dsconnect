import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

// Guarda a sessão no cofre seguro do aparelho (Keychain no iOS, Keystore no
// Android) - nunca em SharedPreferences puro, já que são tokens de acesso à
// conta inteira.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'duedesk_session';

  Future<void> save(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;

    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Sessão gravada em formato antigo/corrompido - trata como deslogado
      // em vez de derrubar o app na abertura.
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}
