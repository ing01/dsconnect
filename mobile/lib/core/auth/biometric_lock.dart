import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_service.dart';

class BiometricState {
  const BiometricState({required this.enabled, required this.locked});

  final bool enabled;
  final bool locked;
}

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

// Aparelho com biometria cadastrada - decide se a tela de login oferece o
// botão de biometria.
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isAvailable(),
);

// "Ativada" = há credencial guardada. Abre o app já trancado quando está
// ativada; o `_RootGate` só mostra a sessão restaurada depois de `unlock()`.
class BiometricLockNotifier extends AsyncNotifier<BiometricState> {
  BiometricService get _service => ref.read(biometricServiceProvider);

  @override
  Future<BiometricState> build() async {
    final enabled = await _service.readCredentials() != null;
    return BiometricState(enabled: enabled, locked: enabled);
  }

  Future<bool> authenticate(String reason) => _service.authenticate(reason);

  Future<SavedCredentials?> credentials() => _service.readCredentials();

  Future<bool> unlock() async {
    if (!await _service.authenticate('Confirme sua identidade para abrir o DSConnect')) return false;
    markUnlocked();
    return true;
  }

  // Login feito (por senha ou biometria) - a sessão nova não precisa de
  // outra leitura.
  void markUnlocked() {
    state = AsyncData(BiometricState(enabled: state.value?.enabled ?? false, locked: false));
  }

  void lock() {
    if (state.value?.enabled != true) return;
    state = const AsyncData(BiometricState(enabled: true, locked: true));
  }

  // Chamado só depois de o login com essas credenciais dar certo, pra nunca
  // guardar uma senha inválida.
  Future<void> enable(String email, String password) async {
    await _service.saveCredentials(email, password);
    state = const AsyncData(BiometricState(enabled: true, locked: false));
  }

  Future<void> disable() async {
    await _service.clearCredentials();
    state = const AsyncData(BiometricState(enabled: false, locked: false));
  }
}

final biometricLockProvider =
    AsyncNotifierProvider<BiometricLockNotifier, BiometricState>(BiometricLockNotifier.new);
