/// Pantalla principal con diseño MD3 limpio.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import '../models/expense.dart';
import '../services/expense_repository.dart';
import '../services/settings_service.dart';
import '../services/tile_channel.dart';
import '../utils/formatters.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/expense_list_item.dart';

class HomeScreen extends StatefulWidget {
  final ExpenseRepository repository;
  final TileChannel tileChannel;
  final SettingsService settingsService;
  const HomeScreen({
    super.key,
    required this.repository,
    required this.tileChannel,
    required this.settingsService,
  });
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late List<Expense> _expenses;
  bool _sheetShown = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.tileChannel.addListener(_onTileEvent);
    WidgetsBinding.instance.addObserver(this);
    if (widget.tileChannel.hasPendingOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_sheetShown) _openSheetFromTile();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.tileChannel.removeListener(_onTileEvent);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.repository.reload().then((_) { if (mounted) setState(_refresh); });
    }
  }

  void _refresh() { _expenses = widget.repository.all; }

  void _onTileEvent() {
    if (widget.tileChannel.hasPendingOpen) _openSheetFromTile();
  }

  void _openSheetFromTile() {
    final typeStr = widget.tileChannel.consumeRequest();
    _openSheet(
      initialType: typeStr != null ? TransactionType.fromName(typeStr) : null,
      closeAppAfter: true,
    );
  }

  Future<void> _openSheet({TransactionType? initialType, bool closeAppAfter = false}) async {
    _sheetShown = true;
    final settings = widget.settingsService.settings;
    final added = await AddExpenseSheet.show(
      context, widget.repository, settings,
      initialType: initialType,
      onExpenseSaved: (expense) async {
        final acc = expense.account;
        final newBalance = expense.type == TransactionType.ingreso
            ? acc.balance + expense.amount
            : acc.balance - expense.amount;
        await widget.settingsService.updateAccount(acc.id, balance: newBalance);
      },
    );
    if (added) setState(_refresh);
    if (closeAppAfter && mounted) widget.tileChannel.finishApp();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final wallets = widget.settingsService.settings.accounts;
    final currency = widget.settingsService.settings.currency;

    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('AppGastos', style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.search_outlined),
                tooltip: 'Buscar',
                onPressed: () => Navigator.pushNamed(context, '/search'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await widget.repository.reload();
              if (mounted) setState(_refresh);
            },
            child: CustomScrollView(
              slivers: [
                // ── Balance ──
                SliverToBoxAdapter(child: _buildBalanceCard(theme, cs, wallets, currency)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                // ── Lista ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('Registros recientes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${_expenses.length} total', style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (_expenses.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(theme),
                  )
                else
                  SliverList.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (_, i) => ExpenseListItem(expense: _expenses[i], currency: currency),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openSheet(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar'),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(ThemeData theme, ColorScheme cs, List wallets, currency) {
    final income = widget.repository.totalIncome;
    final expenses = widget.repository.totalExpenses;
    final bal = income - expenses;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance total', style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
              const SizedBox(height: 4),
              Text(
                formatCurrency(bal, currency: currency),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: bal >= 0 ? cs.onSurface : cs.error,
                ),
              ),
              const SizedBox(height: 16),
              // Stat chips.
              Row(
                children: [
                  _statChip(theme, cs, 'Ingresos', income, Colors.green, currency),
                  const SizedBox(width: 10),
                  _statChip(theme, cs, 'Gastos', expenses, cs.error, currency),
                ],
              ),
              if (wallets.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Billeteras', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: wallets.map((w) {
                    return Chip(
                      avatar: CircleAvatar(backgroundColor: w.color, radius: 8, child: const SizedBox.shrink()),
                      label: Text('${w.name}: ${formatCurrency(w.balance, currency: currency)}',
                        style: TextStyle(fontSize: 12, color: cs.onSurface)),
                      backgroundColor: cs.surfaceContainerHighest,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(ThemeData theme, ColorScheme cs, String label, double amount, Color color, currency) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                  Text(formatCurrency(amount, currency: currency),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Sin registros', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Tocá \"Registrar\" para empezar.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}