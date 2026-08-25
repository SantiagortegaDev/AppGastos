/// Pantalla principal — muestra resumen de ingresos/gastos y el listado.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;

import '../models/expense.dart';
import '../models/account.dart';
import '../services/expense_repository.dart';
import '../services/settings_service.dart';
import '../services/tile_channel.dart';
import '../utils/formatters.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/expense_list_item.dart';
import 'settings_screen.dart';

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
  bool _launchedFromTile = false;

  @override
  void initState() {
    super.initState();
    _refresh();

    widget.tileChannel.addListener(_onTileEvent);
    WidgetsBinding.instance.addObserver(this);

    // Si vino de un tile (cold-start), abrir modal inmediatamente.
    if (widget.tileChannel.hasPendingOpen) {
      _launchedFromTile = true;
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
      widget.repository.reload().then((_) {
        if (mounted) setState(_refresh);
      });
    }
  }

  void _refresh() {
    _expenses = widget.repository.all;
  }

  void _onTileEvent() {
    if (widget.tileChannel.hasPendingOpen) {
      _openSheetFromTile();
    }
  }

  void _openSheetFromTile() {
    final typeStr = widget.tileChannel.consumeRequest();
    _openSheet(
      initialType:
          typeStr != null ? TransactionType.fromName(typeStr) : null,
      closeAppAfter: true,
    );
  }

  Future<void> _openSheet({
    TransactionType? initialType,
    bool closeAppAfter = false,
  }) async {
    _sheetShown = true;
    final settings = widget.settingsService.settings;
    final added = await AddExpenseSheet.show(
      context,
      widget.repository,
      settings,
      initialType: initialType,
      onExpenseSaved: (expense) async {
        // Actualizar balance de la billetera.
        final acc = expense.account;
        final newBalance = expense.type == TransactionType.ingreso
            ? acc.balance + expense.amount
            : acc.balance - expense.amount;
        await widget.settingsService.updateAccount(
          acc.id,
          balance: newBalance,
        );
      },
    );
    if (added) setState(_refresh);

    if (closeAppAfter && mounted) {
      widget.tileChannel.finishApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        final wallets = widget.settingsService.settings.accounts;

        return Scaffold(
          appBar: AppBar(
            title: const Text('AppGastos'),
            actions: [
              IconButton(
                tooltip: 'Ajustes',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                        settingsService: widget.settingsService),
                  ),
                ),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _buildHeader(theme, colorScheme, wallets)),
              if (_expenses.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(theme),
                )
              else
                SliverList.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (ctx, i) =>
                      ExpenseListItem(expense: _expenses[i]),
                ),
            ],
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

  Widget _buildHeader(
      ThemeData theme, ColorScheme colorScheme, List<Account> wallets) {
    final income = widget.repository.totalIncome;
    final expenses = widget.repository.totalExpenses;
    final balance = income - expenses;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: colorScheme.onPrimary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Balance total',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatCurrency(balance),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip(
                  theme, colorScheme, 'Ingresos', income, Colors.green),
              const SizedBox(width: 12),
              _statChip(
                  theme, colorScheme, 'Gastos', expenses, colorScheme.error),
            ],
          ),
          const SizedBox(height: 12),
          // Billeteras
          if (wallets.isNotEmpty) ...[
            Text(
              'Billeteras',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: wallets
                  .map((w) => Chip(
                        avatar: CircleAvatar(
                          backgroundColor: w.color,
                          radius: 10,
                          child: const SizedBox.shrink(),
                        ),
                        label: Text(
                          '${w.name}: ${formatCurrency(w.balance)}',
                          style: TextStyle(
                              color: colorScheme.onPrimary, fontSize: 12),
                        ),
                        backgroundColor:
                            colorScheme.onPrimary.withValues(alpha: 0.2),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${widget.repository.count} ${widget.repository.count == 1 ? "registro" : "registros"}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(ThemeData theme, ColorScheme colorScheme, String label,
      double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                  fontSize: 13)),
          Text(formatCurrency(amount),
              style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  void _showAddTileInfo(BuildContext context) {
    const platform = MethodChannel('appgastos.dev/tile');
    platform
        .invokeMethod<bool>('requestAddTile')
        .then((launched) {
      if (launched != true && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Agregar el tile manualmente'),
            content: const Text(
                'Desliza el panel de ajustes rápidos, toca el lápiz, busca "Registrar gasto" y arrástralo al panel.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    });
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
            Text('Todavía no registraste nada',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Toca "Registrar" abajo o usa el acceso rápido del panel.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
