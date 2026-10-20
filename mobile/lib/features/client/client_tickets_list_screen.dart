import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/widgets/bordered_card.dart';
import '../../core/widgets/pill_label.dart';
import 'client_ticket_create_screen.dart';
import 'client_ticket_detail_screen.dart';
import 'client_ticket_filters_sheet.dart';
import 'models/client_ticket.dart';
import 'providers/client_providers.dart';

enum _TicketViewMode { card, list }

class ClientTicketsListScreen extends ConsumerStatefulWidget {
  const ClientTicketsListScreen({super.key});

  @override
  ConsumerState<ClientTicketsListScreen> createState() => _ClientTicketsListScreenState();
}

class _ClientTicketsListScreenState extends ConsumerState<ClientTicketsListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  _TicketViewMode _viewMode = _TicketViewMode.card;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters(ClientTicketsState state) async {
    final result = await showModalBottomSheet<ClientTicketFiltersResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ClientTicketFiltersSheet(
        teams: state.teams,
        ticketColumns: state.ticketColumns,
        assignees: state.assignees,
        initialTeamId: state.teamId,
        initialTicketColumnId: state.ticketColumnId,
        initialAssigneeId: state.assigneeId,
        initialStatus: state.status,
        initialCreatedAfter: state.createdAfter,
        initialCreatedBefore: state.createdBefore,
      ),
    );
    if (result == null) return;
    await ref.read(clientTicketsProvider.notifier).applyFilters(
          teamId: result.teamId,
          ticketColumnId: result.ticketColumnId,
          assigneeId: result.assigneeId,
          status: result.status,
          createdAfter: result.createdAfter,
          createdBefore: result.createdBefore,
        );
  }

  void _runSearch() => ref.read(clientTicketsProvider.notifier).search(_searchController.text.trim());

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(clientTicketsProvider.notifier).search('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(clientTicketsProvider);
    final state = ticketsAsync.value;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar por número ou assunto',
                      // Toque no icone de busca tambem dispara - alguns
                      // teclados nao tem uma tecla de "ir"/"buscar", e sem
                      // isto nao haveria jeito de confirmar a busca.
                      prefixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _runSearch),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: (state?.activeFilterCount ?? 0) > 0,
                  label: Text('${state?.activeFilterCount ?? 0}'),
                  child: IconButton.outlined(
                    onPressed: state == null ? null : () => _openFilters(state),
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filtros',
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => setState(
                    () => _viewMode = _viewMode == _TicketViewMode.card ? _TicketViewMode.list : _TicketViewMode.card,
                  ),
                  icon: Icon(_viewMode == _TicketViewMode.card ? Icons.view_list_outlined : Icons.view_agenda_outlined),
                  tooltip: _viewMode == _TicketViewMode.card ? 'Ver em lista' : 'Ver em cards',
                ),
              ],
            ),
          ),
          if ((state?.companies.length ?? 0) > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CompanyChip(
                      label: 'Todas as empresas',
                      selected: state!.companyId == null,
                      onTap: () => ref.read(clientTicketsProvider.notifier).filterByCompany(null),
                    ),
                    for (final company in state.companies)
                      _CompanyChip(
                        label: company.name,
                        selected: state.companyId == company.id,
                        onTap: () => ref.read(clientTicketsProvider.notifier).filterByCompany(company.id),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(clientTicketsProvider.notifier).refresh(),
              child: ticketsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    const Center(child: Text('Não foi possível carregar seus chamados.')),
                  ],
                ),
                data: (data) {
                  final tickets = data.tickets;
                  if (tickets.isEmpty) {
                    final isFiltering = data.query.isNotEmpty || data.companyId != null || data.activeFilterCount > 0;
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            isFiltering ? 'Nenhum chamado encontrado.' : 'Você ainda não tem nenhum chamado aberto.',
                          ),
                        ),
                      ],
                    );
                  }
                  return _viewMode == _TicketViewMode.card
                      ? ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: tickets.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _TicketTile(ticket: tickets[index]),
                        )
                      : _TicketGroupedList(tickets: tickets);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: brandGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2781F6).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientTicketCreateScreen()),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Abrir chamado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyChip extends StatelessWidget {
  const _CompanyChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final ClientTicket ticket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BorderedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: ticket.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${ticket.displayId} ${ticket.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd/MM/yy').format(ticket.updatedAt.toLocal()),
                style: TextStyle(fontSize: 11, color: colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ticket.pendingTriage ? 'Aguardando triagem' : '${ticket.teamName} · ${ticket.ticketColumnName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          ),
          if (ticket.assigneeName != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ticket.assigneeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ),
              ],
            ),
          ],
          if (ticket.dueDate != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Entrega: ${DateFormat('dd/MM/yy').format(ticket.dueDate!.toLocal())}',
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              if (ticket.pendingTriage) const PillLabel('Aguardando triagem', colorName: 'amber'),
              PillLabel(statusLabels[ticket.status] ?? ticket.status, colorName: statusColorName(ticket.status)),
              PillLabel(
                priorityLabels[ticket.priority] ?? ticket.priority,
                colorName: priorityColorName(ticket.priority),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Mesmo espirito do Portal web: os chamados agrupados por Estagio (com a
// Mesa junto no titulo, ja que o mesmo nome de Estagio existe em varias
// Mesas), cada grupo recolhivel.
class _TicketGroupedList extends StatelessWidget {
  const _TicketGroupedList({required this.tickets});

  final List<ClientTicket> tickets;

  String _groupKeyFor(ClientTicket ticket) =>
      ticket.pendingTriage ? 'Aguardando triagem' : '${ticket.teamName} · ${ticket.ticketColumnName}';

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ClientTicket>>{};
    for (final ticket in tickets) {
      groups.putIfAbsent(_groupKeyFor(ticket), () => []).add(ticket);
    }
    final groupKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Aguardando triagem') return -1;
        if (b == 'Aguardando triagem') return 1;
        return a.compareTo(b);
      });

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final key in groupKeys)
          ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              '$key (${groups[key]!.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            children: [for (final ticket in groups[key]!) _TicketListRow(ticket: ticket)],
          ),
      ],
    );
  }
}

class _TicketListRow extends StatelessWidget {
  const _TicketListRow({required this.ticket});

  final ClientTicket ticket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ClientTicketDetailScreen(ticketId: ticket.id)),
      ),
      title: Text(
        '#${ticket.displayId} ${ticket.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: ticket.assigneeName != null
          ? Text(
              ticket.assigneeName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PillLabel(statusLabels[ticket.status] ?? ticket.status, colorName: statusColorName(ticket.status)),
          const SizedBox(height: 2),
          if (ticket.dueDate != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 10, color: colorScheme.outline),
                const SizedBox(width: 3),
                Text(
                  DateFormat('dd/MM/yy').format(ticket.dueDate!.toLocal()),
                  style: TextStyle(fontSize: 10, color: colorScheme.outline),
                ),
              ],
            )
          else
            Text(
              DateFormat('dd/MM/yy').format(ticket.updatedAt.toLocal()),
              style: TextStyle(fontSize: 10, color: colorScheme.outline),
            ),
        ],
      ),
    );
  }
}
