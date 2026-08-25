/**
 * Bottom sheet de registro: tipo → monto → categoría → billetera → comentario.
 *
 * - Si [initialType] no es null, salta la selección de tipo.
 * - El paso de comentario solo se muestra si [askForComment] es true.
 * - Al guardar se dispara el webhook (si está configurado) y se actualiza
 *   el balance de la billetera.
 */
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
  final TransactionType? initialType;
  final Future<void> Function(Expense)? onExpenseSaved;

  const AddExpenseSheet({
    super.key,
    required this.repository,
    required this.settings,
    this.initialType,
    this.onExpenseSaved,
  });

  static Future<bool> show(
    BuildContext context,
    ExpenseRepository repository,
    AppSettings settings, {
    TransactionType? initialType,
    Future<void> Function(Expense)? onExpenseSaved,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AddExpenseSheet(
        repository: repository,
        settings: settings,
        initialType: initialType,
        onExpenseSaved: onExpenseSaved,
      ),
    );
    return result ?? false;
  }

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet>
    with SingleTickerProviderStateMixin {
  late TransactionType _selectedType;
  late int _step;
  late List<ExpenseCategory> _categories;
  late List<Account> _accounts;
  late bool _showCommentStep;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  bool _saving = false;
  double _amount = 0;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TransactionType.gasto;
    _categories = ExpenseCategory.forType(_selectedType);
    _accounts = widget.settings.accounts;
    _showCommentStep = widget.settings.askForComment;
    // Si viene con tipo pre-seleccionado, saltar paso 0.
    _step = widget.initialType != null ? 1 : 0;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  // ── Navegación entre pasos ──

  void _goToStep(int step) {
    setState(() {
      _step = step;
      if (step == 2) {
        _categories = ExpenseCategory.forType(_selectedType);
      }
      if (step == 1) {
        _amountFocus.requestFocus();
      }
    });
  }

  Future<void> _save(Account account) async {
    if (_saving) return;
    setState(() => _saving = true);

    final expense = Expense.create(
      amount: _amount,
      category: _categories.first, // Se sobreescribe abajo
      account: account,
      type: _selectedType,
      comment: _showCommentStep ? _commentCtrl.text.trim() : '',
    );

    // Re-crear con la categoría seleccionada en paso 2.
    final realExpense = Expense(
      id: expense.id,
      amount: expense.amount,
      category: _selectedCategory!,
      account: account,
      date: expense.date,
      type: expense.type,
      comment: expense.comment,
    );

    await widget.repository.add(realExpense);

    // Actualizar balance de la billetera.
    final newBalance = _selectedType == TransactionType.ingreso
        ? account.balance + realExpense.amount
        : account.balance - realExpense.amount;
    if (widget.onExpenseSaved != null) {
      await widget.onExpenseSaved!(realExpense);
    }

    // Webhook.
    await WebhookService.fireIfConfigured(
      webhookUrl: widget.settings.webhookUrl,
      expense: realExpense,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  ExpenseCategory? _selectedCategory;

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: _buildStep(theme, colorScheme),
        ),
      ),
    );
  }

  Widget _buildStep(ThemeData theme, ColorScheme colorScheme) {
    switch (_step) {
      case 0:
        return _buildTypeSelection(theme, colorScheme);
      case 1:
        return _buildAmountStep(theme, colorScheme);
      case 2:
        return _buildCategoryStep(theme, colorScheme);
      case 3:
        return _buildAccountStep(theme, colorScheme);
      case 4:
        return _buildCommentStep(theme, colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Paso 0: Tipo de registro ──

  Widget _buildTypeSelection(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Qué querés registrar?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _typeCard(
                    theme: theme,
                    type: TransactionType.gasto,
                    color: colorScheme.error,
                    icon: Icons.arrow_downward_rounded,
                    label: 'Gasto',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _typeCard(
                    theme: theme,
                    type: TransactionType.ingreso,
                    color: Colors.green,
                    icon: Icons.arrow_upward_rounded,
                    label: 'Ingreso',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _typeCard({
    required ThemeData theme,
    required TransactionType type,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _selectedType = type;
            _categories = ExpenseCategory.forType(type);
          });
          _goToStep(1);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Paso 1: Monto ──

  Widget _buildAmountStep(ThemeData theme, ColorScheme colorScheme) {
    final isGasto = _selectedType == TransactionType.gasto;
    final accentColor = isGasto ? colorScheme.error : Colors.green;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con botón volver (solo si hay paso 0).
            if (widget.initialType == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _goToStep(0),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Tipo'),
                ),
              ),
            Text(
              isGasto ? '¿Cuánto gastaste?' : '¿Cuánto recibiste?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Display del monto.
            Text(
              _amountCtrl.text.isEmpty
                  ? formatCurrency(0)
                  : formatCurrency(_amount),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 16),
            // TextField oculto para el teclado.
            TextField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                _CommaDotInputFormatter(),
              ],
              style: const TextStyle(fontSize: 0, height: 0),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) {
                final cleaned = v.replaceAll(',', '.');
                final parsed = double.tryParse(cleaned) ?? 0;
                setState(() => _amount = parsed);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _amount > 0 ? () => _goToStep(2) : null,
                child: const Text('Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 2: Categoría ──

  Widget _buildCategoryStep(ThemeData theme, ColorScheme colorScheme) {
    final isGasto = _selectedType == TransactionType.gasto;
    final accentColor = isGasto ? colorScheme.error : Colors.green;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goToStep(1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Monto'),
              ),
            ),
            Text(
              isGasto ? '¿En qué categoría?' : '¿De dónde viene?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return ActionChip(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _selectedCategory = cat),
                  avatar: Icon(cat.icon,
                      color: selected ? accentColor : theme.colorScheme.onSurface),
                  label: Text(cat.label),
                  labelStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: selected ? FontWeight.bold : null,
                    color: selected ? accentColor : null,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: selected
                        ? BorderSide(color: accentColor, width: 2)
                        : BorderSide.none,
                  ),
                  backgroundColor:
                      selected ? accentColor.withValues(alpha: 0.1) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _selectedCategory != null && !_saving ? () => _goToStep(3) : null,
                child: const Text('Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 3: Billetera ──

  Widget _buildAccountStep(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goToStep(2),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Categoría'),
              ),
            ),
            Text(
              '¿Desde qué billetera?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: _accounts.map((acc) {
                return ActionChip(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_showCommentStep) {
                            _goToStep(4);
                            // Guardar referencia para el save.
                            _pendingAccount = acc;
                          } else {
                            _save(acc);
                          }
                        },
                  avatar: CircleAvatar(
                    backgroundColor: acc.color,
                    radius: 12,
                    child: const SizedBox.shrink(),
                  ),
                  label: Text(acc.name),
                  labelStyle: theme.textTheme.titleMedium,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        ),
      ),
    );
  }

  Account? _pendingAccount;

  // ── Paso 4: Comentario (opcional) ──

  Widget _buildCommentStep(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goToStep(3),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Billetera'),
              ),
            ),
            Text(
              '¿Algún comentario?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Opcional — podés dejarlo vacío',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Ej: almuerzo con el equipo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (_pendingAccount != null) _save(_pendingAccount!);
                      },
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _selectedType == TransactionType.gasto
                            ? 'Registrar gasto'
                            : 'Registrar ingreso',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formatter que normaliza comas y puntos decimales ──

class _CommaDotInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    // Permitir solo un punto decimal.
    final parts = text.split('.');
    if (parts.length > 2) {
      return oldValue;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
