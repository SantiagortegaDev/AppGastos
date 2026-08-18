/// Pantalla principal.
///
/// Header rediseñado con:
///  - Tipografía grande para el total.
///  - Gradiente sutil derivado del color semilla del tema.
///  - Card de "cantidad de gastos" accesoria.
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
  late double _total;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.tileChannel.addListener(_onTileEvent);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.tileChannel.removeListener(_onTileEvent);
    super.dispose();
  }

  /// Cuando la app vuelve a foreground (después de que el overlay pudo
  /// haber guardado un gasto), recargamos desde disco.
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
    _total = widget.repository.total;
  }

  void _onTileEvent() {
    if (widget.tileChannel.pendingOpenRequest) {
      widget.tileChannel.consumeOpenRequest();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAddExpenseSheet();
      });
    }
  }

  Future<void> _openAddExpenseSheet() async {
    final settings = widget.settingsService.settings;
    final added = await AddExpenseSheet.show(
      context,
      widget.repository,
      settings,
    );
    if (added) setState(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = widget.settingsService.settings;

    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('AppGastos'),
            actions: [
              IconButton(
                tooltip: 'Ajustes',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsScreen(settingsService: widget.settingsService),
                  ),
                ),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // ───── Header con total ─────
              SliverToBoxAdapter(child: _buildHeader(theme, colorScheme)),
              // ───── Lista ─────
              if (_expenses.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(theme),
                )
              else
                SliverList.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (ctx, i) => ExpenseListItem(expense: _expenses[i]),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddExpenseSheet,
            icon: const Icon(Icons.add),
            label: const Text('Registrar gasto'),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
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
          // Pequeño título con icono.
          Row(
            children: [
              Icon(Icons.savings_outlined,
                  color: colorScheme.onPrimary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Total gastado',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Total grande con animación implícita al cambiar.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              formatCurrency(_total),
              key: ValueKey(_total),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_expenses.length} ${_expenses.length == 1 ? "gasto" : "gastos"} registrados',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          // Botón "Agregar acceso rápido" como FilledButton blanco.
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: () => _showAddTileInfo(context),
              icon: Icon(Icons.dashboard_customize_outlined,
                  color: colorScheme.primary, size: 18),
              label: Text(
                'Agregar acceso rápido',
                style: TextStyle(color: colorScheme.primary),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onPrimary,
                foregroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTileInfo(BuildContext context) {
    const platform = MethodChannel('appgastos.dev/tile');
    platform.invokeMethod<bool>('requestAddTile').then((launched) {
      if (launched != true && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Agregar el tile manualmente'),
            content: const Text(
                'Desliza el panel de ajustes rápidos desde arriba, toca el '
                'lápiz ("Editar"), busca "Registrar gasto" y arrástralo al panel.'),
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
            Text('Todavía no registraste gastos',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Toca "Registrar gasto" abajo o usa el acceso rápido del panel.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
