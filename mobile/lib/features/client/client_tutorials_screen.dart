import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/bordered_card.dart';
import 'models/client_tutorial.dart';
import 'providers/client_providers.dart';

// A aba "Tutoriais": os modulos (DS Connect, DS Comercial...) aparecem como cards; ao tocar, abrem os
// videos de dentro. Tudo e' cadastrado pela equipe em Configuracoes > Tutoriais do Portal; so os
// ativos chegam, na ordem definida pelo administrador. Sem nenhum modulo, a lista de videos aparece
// direto. O video abre no player do aparelho (YouTube/Vimeo no app ou no navegador).
class ClientTutorialsScreen extends ConsumerStatefulWidget {
  const ClientTutorialsScreen({super.key});

  @override
  ConsumerState<ClientTutorialsScreen> createState() => _ClientTutorialsScreenState();
}

// Distingue "nenhum card aberto" (null) de "card Geral aberto" (que tem id nulo).
class _OpenCard {
  const _OpenCard(this.moduleId);
  final int? moduleId;
}

class _ClientTutorialsScreenState extends ConsumerState<ClientTutorialsScreen> {
  _OpenCard? _open;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientTutorialsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(clientTutorialsProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: const [SizedBox(height: 80), Center(child: Text('Não foi possível carregar os tutoriais.'))],
          ),
          data: _buildData,
        ),
      ),
    );
  }

  Widget _buildData(TutorialsResult result) {
    if (result.tutorials.isEmpty) {
      return ListView(
        children: const [SizedBox(height: 80), Center(child: Text('Nenhum tutorial disponível por enquanto.'))],
      );
    }

    final cards = result.cards;
    final open = _open;
    final openCard = open == null ? null : cards.where((card) => card.moduleId == open.moduleId).firstOrNull;

    // Sem modulos com video: a lista aparece direto.
    final videos = cards.isEmpty
        ? result.tutorials
        : (openCard == null ? const <ClientTutorial>[] : result.tutorialsOf(openCard.moduleId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (openCard != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar'),
            ),
          ),
          Text(openCard.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (openCard.description != null) ...[
            const SizedBox(height: 4),
            Text(openCard.description!),
          ],
          const SizedBox(height: 12),
        ] else
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Aprenda a usar o sistema com vídeos curtos.'),
          ),
        if (cards.isNotEmpty && openCard == null)
          for (final card in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModuleCard(card: card, onTap: () => setState(() => _open = _OpenCard(card.moduleId))),
            )
        else
          for (final tutorial in videos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TutorialTile(tutorial: tutorial),
            ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.card, required this.onTap});

  final TutorialCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BorderedCard(
      onTap: onTap,
      child: Row(
        children: [
          if (card.logoUrl != null)
            Image.network(
              card.logoUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(Icons.play_circle_outline, size: 40, color: colorScheme.primary),
            )
          else
            Icon(Icons.play_circle_outline, size: 40, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (card.description != null) ...[
                  const SizedBox(height: 2),
                  Text(card.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text(
                  card.count == 1 ? '1 vídeo' : '${card.count} vídeos',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

// Cada video comeca recolhido (so o titulo); ao tocar, mostra a descricao e o botao de assistir.
class _TutorialTile extends StatelessWidget {
  const _TutorialTile({required this.tutorial});

  final ClientTutorial tutorial;

  Future<void> _watch(BuildContext context) async {
    final address = tutorial.videoAddress;
    final uri = address == null ? null : Uri.tryParse(address);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o vídeo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = tutorial.videoAddress != null;

    return BorderedCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(tutorial.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          children: [
            if (tutorial.description != null) ...[
              Text(tutorial.description!),
              const SizedBox(height: 12),
            ],
            if (hasVideo)
              FilledButton.icon(
                onPressed: () => _watch(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Assistir vídeo'),
              )
            else
              const Text('O vídeo deste tutorial estará disponível em breve.'),
          ],
        ),
      ),
    );
  }
}
