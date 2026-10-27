import 'package:flutter/material.dart';

// Item de menu das telas iniciais pra desligar a biometria (apaga a
// credencial guardada). Ativar é na tela de login, onde a senha é digitada.
class BiometricMenuTile extends StatelessWidget {
  const BiometricMenuTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.fingerprint),
      title: Text('Desativar biometria'),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
