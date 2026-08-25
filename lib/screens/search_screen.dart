/// Pantalla de búsqueda y filtros.
library;

import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/account.dart';
import '../services/expense_repository.dart';
import '../services/settings_service.dart';
import '../widgets/expense_list_item.dart';

class SearchScreen extends StatefulWidget {
  final ExpenseRepository repository;
  final SettingsService settingsService;
  const SearchScreen({super.key, required this.repository, required this.settingsService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  TransactionType? _typeFilter;
  String? _accountFilter;
  List<Expense> _results = [];

  @override
  void initState() {
    super.initState();
    _doSearch();
    _queryCtrl.addListener(_doSearch);
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _doSearch() {
    final r = widget.repository.filter(
      query: _queryCtrl.text,
      type: _typeFilter,
      accountId: _accountFilter,
    );
    setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cur = widget.settingsService.settings.currency;
    final accounts = widget.settingsService.settings.accounts;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar por comentario, categoría, monto...',
            border: InputBorder.none,
            filled: false,
          ),
          style: theme.textTheme.bodyLarge,
        ),
      ),
      body: Column(
        children: [
          // Filtros.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _typeFilter == null,
                    onSelected: (_) => setState(() { _typeFilter = null; _doSearch(); }),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.arrow_downward, size: 16, color: Colors.red),
                    label: const Text('Gastos'),
                    selected: _typeFilter == TransactionType.gasto,
                    onSelected: (_) => setState(() { _typeFilter = TransactionType.gasto; _doSearch(); }),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.arrow_upward, size: 16, color: Colors.green),
                    label: const Text('Ingresos'),
                    selected: _typeFilter == TransactionType.ingreso,
                    onSelected: (_) => setState(() { _typeFilter = TransactionType.ingreso; _doSearch(); }),
                  ),
                  const SizedBox(width: 8),
                  // Billetera filter.
                  DropdownButton<String>(
                    hint: const Text('Billetera'),
                    value: _accountFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setState(() { _accountFilter = v; _doSearch(); }),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Resultados.
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text('Sin resultados', style: theme.textTheme.bodyLarge?.copyWith(color: cs.outline)))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) => ExpenseListItem(expense: _results[i], currency: cur),
                  ),
          ),
        ],
      ),
    );
  }
}