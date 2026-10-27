import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

typedef SavedCredentials = ({String email, String password});

// Face ID / digital pra entrar sem digitar a senha: o e-mail e a senha ficam
// no cofre seguro do aparelho (Keychain/Keystore) e só são usados depois de
// uma leitura biométrica bem-sucedida. Ter credencial guardada é o que
// significa "biometria ativada".
class BiometricService {
  BiometricService({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;
  static const _credentialsKey = 'duedesk_biometric_credentials';

  // Aparelho sem leitor, ou com leitor mas sem nenhuma digital/rosto
  // cadastrado, não tem como usar o recurso.
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // `biometricOnly` impede o PIN do aparelho como atalho - quem não consegue
  // usar a biometria cai na opção de digitar a senha.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      // Cancelado, travado por excesso de tentativas, biometria removida
      // do aparelho... pro app é tudo "não autenticou".
      return false;
    }
  }

  Future<SavedCredentials?> readCredentials() async {
    final raw = await _storage.read(key: _credentialsKey);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (email: json['email'] as String, password: json['password'] as String);
    } catch (_) {
      await clearCredentials();
      return null;
    }
  }

  Future<void> saveCredentials(String email, String password) =>
      _storage.write(key: _credentialsKey, value: jsonEncode({'email': email, 'password': password}));

  Future<void> clearCredentials() => _storage.delete(key: _credentialsKey);
}
