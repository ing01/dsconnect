import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/biometric_lock.dart';
import '../../core/theme/app_theme.dart';

// Mostrada no lugar da sessão restaurada enquanto a biometria não for
// confirmada. Pede a leitura sozinha ao abrir; se falhar, o botão repete e
// "Usar senha" desloga pra cair no login normal.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await ref.read(biometricLockProvider.notifier).unlock();
    if (!ok && mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/images/logo.png', width: 84, height: 84)),
                  const SizedBox(height: 20),
                  const Text(
                    'DSConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _failed ? 'Não foi possível confirmar sua identidade.' : 'Confirme sua identidade para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _failed ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    onPressed: _unlock,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint, size: 22),
                        SizedBox(width: 8),
                        Text('Desbloquear'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.read(sessionProvider.notifier).logout(),
                    child: const Text('Usar senha'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
