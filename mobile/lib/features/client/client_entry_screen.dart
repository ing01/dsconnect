import 'package:flutter/material.dart';

const _brandBlue = Color(0xFF2781F6);

// A tela de ENTRADA do modo cliente: só três opções, bem grandes - "Falar com a
// equipe", "Abrir chamado" e "Acessar o portal completo" (a tela comum, com as
// abas). Sem abas aqui: a barra de baixo só aparece depois da escolha.
//
// Aparece a CADA abertura do app (e a cada login) e nada é lembrado de uma vez
// para a outra - escolher o portal completo hoje não pula esta tela amanhã.
// Quem decide o que cada botão faz é o shell (`ClientHomeShell`), que também
// garante que o Chat só abre - e só cria a conversa no servidor - se a pessoa
// escolher "Falar com a equipe".
class ClientEntryScreen extends StatelessWidget {
  const ClientEntryScreen({
    super.key,
    required this.onTalkToTeam,
    required this.onOpenTicket,
    required this.onFullPortal,
    this.actions = const [],
  });

  final VoidCallback onTalkToTeam;
  final VoidCallback onOpenTicket;
  final VoidCallback onFullPortal;
  // O menu de três pontinhos (minha conta, sair...) continua à mão aqui.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DSConnect'), actions: actions),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EntryButton(
                    icon: Icons.chat_bubble_outline,
                    title: 'Falar com a equipe',
                    hint: 'Converse com a equipe agora.',
                    onTap: onTalkToTeam,
                  ),
                  const SizedBox(height: 16),
                  _EntryButton(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Abrir chamado',
                    hint: 'Registre um problema ou pedido e acompanhe o andamento.',
                    onTap: onOpenTicket,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: onFullPortal,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Acessar o portal completo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
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

class _EntryButton extends StatelessWidget {
  const _EntryButton({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _brandBlue,
      elevation: 3,
      shadowColor: _brandBlue.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(hint, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
