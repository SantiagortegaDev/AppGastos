/// Pantalla principal.
///
/// Muestra:
///  - Total acumulado de gastos (cabecera destacada).
///  - Lista de gastos ordenados del más reciente al más antiguo.
///  - FAB "Registrar gasto" que abre el bottom sheet de 2 pasos.
///  - Botón "Agregar acceso rápido" si el tile todavía no fue agregado.
///
/// Se suscribe al [TileChannel] para abrir el sheet automáticamente cuando
/// el usuario toque el Tile nativo del panel de ajustes rápidos.
library;

import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/expense_repository.dart';
import '../services/tile_channel.dart';
import '../utils/formatters.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/add_quick_tile_button.dart';
import '../widgets/expense_list_item.dart';

class HomeScreen extends StatefulWidget {
  final ExpenseRepository repository;
  final TileChannel tileChannel;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.tileChannel,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late List<Expense> _expenses;
  late double _total;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.tileChannel.addListener(_onTileEvent);
  }

  @override
  void dispose() {
    widget.tileChannel.removeListener(_onTileEvent);
    super.dispose();
  }

  void _refresh() {
    _expenses = widget.repository.all;
    _total = widget.repository.total;
  }

  /// Reacciona a un evento del TileChannel (apertura solicitada).
  void _onTileEvent() {
    if (widget.tileChannel.pendingOpenRequest) {
      widget.tileChannel.consumeOpenRequest();
      // Post-frame para asegurar que el contexto esté listo.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAddExpenseSheet();
      });
    }
  }

  Future<void> _openAddExpenseSheet() async {
    final added = await AddExpenseSheet.show(context, widget.repository);
    if (added) {
      setState(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AppGastos'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cabecera con total acumulado.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total gastado',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(_total),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                AddQuickTileButton(tileChannel: widget.tileChannel),
              ],
            ),
          ),
          // Lista de gastos.
          Expanded(
            child: _expenses.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _expenses.length,
                    itemBuilder: (ctx, i) => ExpenseListItem(
                      expense: _expenses[i],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseSheet,
        icon: const Icon(Icons.add),
        label: const Text('Registrar gasto'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Todavía no registraste gastos',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Toca "Registrar gasto" abajo o usa el acceso rápido del panel '
              'de ajustes rápidos para empezar.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
