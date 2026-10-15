import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/filter_option.dart';

class ClientTicketFiltersResult {
  const ClientTicketFiltersResult({
    this.teamId,
    this.ticketColumnId,
    this.assigneeId,
    this.createdAfter,
    this.createdBefore,
  });

  final int? teamId;
  final int? ticketColumnId;
  final int? assigneeId;
  final String? createdAfter;
  final String? createdBefore;
}

// Modal de filtros (Mesa, Estagio, Responsavel, Periodo) - so' busca de novo
// quando a pessoa confirma com "Aplicar", nao a cada escolha.
class ClientTicketFiltersSheet extends StatefulWidget {
  const ClientTicketFiltersSheet({
    required this.teams,
    required this.ticketColumns,
    required this.assignees,
    this.initialTeamId,
    this.initialTicketColumnId,
    this.initialAssigneeId,
    this.initialCreatedAfter,
    this.initialCreatedBefore,
    super.key,
  });

  final List<FilterOption> teams;
  final List<FilterOption> ticketColumns;
  final List<FilterOption> assignees;
  final int? initialTeamId;
  final int? initialTicketColumnId;
  final int? initialAssigneeId;
  final String? initialCreatedAfter;
  final String? initialCreatedBefore;

  @override
  State<ClientTicketFiltersSheet> createState() => _ClientTicketFiltersSheetState();
}

class _ClientTicketFiltersSheetState extends State<ClientTicketFiltersSheet> {
  int? _teamId;
  int? _ticketColumnId;
  int? _assigneeId;
  DateTime? _createdAfter;
  DateTime? _createdBefore;

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _apiDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _teamId = widget.initialTeamId;
    _ticketColumnId = widget.initialTicketColumnId;
    _assigneeId = widget.initialAssigneeId;
    _createdAfter = widget.initialCreatedAfter != null ? DateTime.tryParse(widget.initialCreatedAfter!) : null;
    _createdBefore = widget.initialCreatedBefore != null ? DateTime.tryParse(widget.initialCreatedBefore!) : null;
  }

  Future<void> _pickDate({required bool isAfter}) async {
    final initial = (isAfter ? _createdAfter : _createdBefore) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isAfter) {
        _createdAfter = picked;
      } else {
        _createdBefore = picked;
      }
    });
  }

  void _clearAll() {
    setState(() {
      _teamId = null;
      _ticketColumnId = null;
      _assigneeId = null;
      _createdAfter = null;
      _createdBefore = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      ClientTicketFiltersResult(
        teamId: _teamId,
        ticketColumnId: _ticketColumnId,
        assigneeId: _assigneeId,
        createdAfter: _createdAfter != null ? _apiDateFormat.format(_createdAfter!) : null,
        createdBefore: _createdBefore != null ? _apiDateFormat.format(_createdBefore!) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(onPressed: _clearAll, child: const Text('Limpar')),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.teams.length > 1) ...[
            _FilterDropdown(
              label: 'Mesa',
              value: _teamId,
              options: widget.teams,
              onChanged: (value) => setState(() => _teamId = value),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.ticketColumns.isNotEmpty) ...[
            _FilterDropdown(
              label: 'Estágio',
              value: _ticketColumnId,
              options: widget.ticketColumns,
              onChanged: (value) => setState(() => _ticketColumnId = value),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.assignees.isNotEmpty) ...[
            _FilterDropdown(
              label: 'Responsável',
              value: _assigneeId,
              options: widget.assignees,
              onChanged: (value) => setState(() => _assigneeId = value),
            ),
            const SizedBox(height: 12),
          ],
          Text('Período', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isAfter: true),
                  child: Text(_createdAfter != null ? _dateFormat.format(_createdAfter!) : 'De'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isAfter: false),
                  child: Text(_createdBefore != null ? _dateFormat.format(_createdBefore!) : 'Até'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _apply, child: const Text('Aplicar filtros')),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<FilterOption> options;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        for (final option in options) DropdownMenuItem(value: option.id, child: Text(option.name)),
      ],
      onChanged: onChanged,
    );
  }
}
