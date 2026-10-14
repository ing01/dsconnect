import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// O servidor ainda nao tem estado de lido/nao-lido pra notificacao do
// cliente (ver comentario em Api::V1::Client::NotificationsController) -
// entao "sumir ao clicar" e' local, por aparelho, ate essa coluna existir
// de verdade no backend.
class NotificationDismissStore {
  NotificationDismissStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'dismissed_client_notifications';

  Future<Set<String>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> dismiss(String id) async {
    final ids = await read();
    if (!ids.add(id)) return;
    await _storage.write(key: _key, value: jsonEncode(ids.toList()));
  }
}
