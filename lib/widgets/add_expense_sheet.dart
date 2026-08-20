/// Bottom sheet Material de 3 pasos para registrar un gasto.
///
/// Paso 1: Monto.
///   - TextField numérico sin hintText ni prefixText para evitar el bug
///     del cursor superpuesto al placeholder "0".
///   - En su lugar, mostramos un `Text` grande arriba que se actualiza
///     en vivo a medida que el usuario escribe (o muestra "$0" si vacío).
///   - Botón "Siguiente" habilitado solo si monto > 0.
///
/// Paso 2: Categoría (chips con ícono).
/// Paso 3: Cuenta (chips con color).
///   - Al tocar una cuenta, se guarda el gasto y se cierra el sheet.
///
/// Manejo del teclado: `isScrollControlled: true` + `Padding(viewInsets.bottom)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account.dart';
import '../models/app_settings.dart';
import '../models/expense.dart';
import '../services/expense_repository.dart';
import '../services/webhook_service.dart';
import '../utils/formatters.dart';

class AddExpenseSheet extends StatefulWidget {
  final ExpenseRepository repository;
  final AppSettings settings;
  final Future<void> Function(Expense)? onExpenseSaved;

  const AddExpenseSheet({
    super.key,
    required this.repository,
    required this.settings,
    this.onExpenseSaved,
  });

  static Future<bool> show(
    BuildContext context,
    ExpenseRepository repository,
    AppSettings settings, {
    Future<void> Function(Expense)? onExpenseSaved,
    bool transparentBarrier = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: transparentBarrier ? Colors.transparent : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AddExpenseSheet(
        repository: repository,
        settings: settings,
        onExpenseSaved: onExpenseSaved,
      ),
    );
    return result ?? false;
  }

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  int _step = 1; // 1 = monto, 2 = categoría, 3 = cuenta
  final TextEditingController _amountCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  bool _saving = false;
  late ExpenseCategory _selectedCategory;
  late List<Account> _accounts;

  @override
  void initState() {
    super.initState();
    _selectedCategory = ExpenseCategory.comida;
    _accounts = widget.settings.accounts;
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double? _parsedAmount() {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String get _displayAmount {
    final v = _parsedAmount();
    if (v == null || v == 0) return '\$0';
    return formatCurrency(v);
  }

  void _goNext() {
    final value = _parsedAmount();
    if (value == null || value <= 0) return;
    setState(() => _step = 2);
    _amountFocus.unfocus();
  }

  Future<void> _save(Account account) async {
    if (_saving) return;
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);

    final expense = Expense.create(
      amount: amount,
      category: _selectedCategory,
      account: account,
    );
    await widget.repository.add(expense);
    // Webhook fire-and-forget (no bloquea UI).
    WebhookService.fireIfConfigured(
      webhookUrl: widget.settings.webhookUrl,
      expense: expense,
    );
    if (widget.onExpenseSaved != null) {
      await widget.onExpenseSaved!(expense);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _step == 1
              ? _buildStep1(theme)
              : _step == 2
                  ? _buildStep2(theme)
                  : _buildStep3(theme),
        ),
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  // ───────── Paso 1: Monto ─────────
  Widget _buildStep1(ThemeData theme) {
    final isValid = (_parsedAmount() ?? 0) > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDragHandle(theme),
        Text(
          '¿Cuánto gastaste?',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Display grande del monto (se actualiza en vivo).
        // Esto reemplaza el `prefixText` + `hintText` anterior que causaba
        // superposición con el cursor.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _displayAmount,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isValid
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountCtrl,
          focusNode: _amountFocus,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _goNext(),
          decoration: InputDecoration(
            hintText: 'Escribe el monto',
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isValid ? _goNext : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Siguiente'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  // ───────── Paso 2: Categoría ─────────
  Widget _buildStep2(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDragHandle(theme),
        Text('Gasto a registrar',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          _displayAmount,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text('¿En qué categoría?',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: ExpenseCategory.values.map((cat) {
            final selected = cat == _selectedCategory;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedCategory = cat);
                // Avanzamos automáticamente al paso 3 al elegir categoría.
                setState(() => _step = 3);
              },
              avatar: Icon(cat.icon),
              label: Text(cat.label),
              labelStyle: theme.textTheme.titleMedium,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _saving ? null : () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Cambiar monto'),
        ),
      ],
    );
  }

  // ───────── Paso 3: Cuenta ─────────
  Widget _buildStep3(ThemeData theme) {
    if (_accounts.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(theme),
          const Text('No tienes cuentas configuradas.'),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDragHandle(theme),
        Text('Gasto a registrar',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          _displayAmount,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text('${_selectedCategory.label}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Text('¿Desde qué cuenta?',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: _accounts.map((acc) {
            return ActionChip(
              onPressed: _saving ? null : () => _save(acc),
              avatar: CircleAvatar(
                backgroundColor: acc.color,
                radius: 12,
                child: const SizedBox.shrink(),
              ),
              label: Text(acc.name),
              labelStyle: theme.textTheme.titleMedium,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _saving ? null : () => setState(() => _step = 2),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Cambiar categoría'),
        ),
      ],
    );
  }
}
