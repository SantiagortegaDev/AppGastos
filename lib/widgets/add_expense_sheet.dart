/**
 * Bottom sheet de registro: tipo → monto → categoría → billetera → comentario.
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

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  late TransactionType _selectedType;
  late int _step;
  late List<ExpenseCategory> _categories;
  late List<Account> _accounts;
  late bool _showCommentStep;

  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  bool _saving = false;
  double _amount = 0;
  ExpenseCategory? _selectedCategory;
  Account? _pendingAccount;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TransactionType.gasto;
    _categories = ExpenseCategory.forType(_selectedType);
    _accounts = widget.settings.accounts;
    _showCommentStep = widget.settings.askForComment;
    _step = widget.initialType != null ? 1 : 0;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() {
      _step = step;
      if (step == 2) _categories = ExpenseCategory.forType(_selectedType);
      if (step == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _amountFocus.requestFocus();
        });
      }
    });
  }

  Future<void> _save(Account account) async {
    if (_saving || _selectedCategory == null) return;
    setState(() => _saving = true);

    final expense = Expense.create(
      amount: _amount,
      category: _selectedCategory!,
      account: account,
      type: _selectedType,
      comment: _showCommentStep ? _commentCtrl.text.trim() : '',
    );

    await widget.repository.add(expense);

    // Actualizar balance de la billetera.
    final newBalance = _selectedType == TransactionType.ingreso
        ? account.balance + expense.amount
        : account.balance - expense.amount;
    if (widget.onExpenseSaved != null) {
      await widget.onExpenseSaved!(expense);
    }
    await WebhookService.fireIfConfigured(webhookUrl: widget.settings.webhookUrl, expense: expense);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: switch (_step) {
            0 => _buildTypeSelection(context),
            1 => _buildAmountStep(context),
            2 => _buildCategoryStep(context),
            3 => _buildAccountStep(context),
            4 => _buildCommentStep(context),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  // ── Paso 0: Tipo (ingreso primero) ──

  Widget _buildTypeSelection(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Qué querés registrar?',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _typeCard(
                    type: TransactionType.ingreso,
                    color: Colors.green,
                    icon: Icons.arrow_upward_rounded,
                    label: 'Ingreso',
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _typeCard(
                    type: TransactionType.gasto,
                    color: theme.colorScheme.error,
                    icon: Icons.arrow_downward_rounded,
                    label: 'Gasto',
                    theme: theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeCard({required TransactionType type, required Color color, required IconData icon, required String label, required ThemeData theme}) {
    return Material(
      color: color.withValues(alpha: 0.08),
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
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 10),
              Text(label, style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Paso 1: Monto ──

  Widget _buildAmountStep(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isGasto = _selectedType == TransactionType.gasto;
    final accent = isGasto ? cs.error : Colors.green;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.initialType == null)
              TextButton.icon(
                onPressed: () => _goToStep(0),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Tipo'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            const SizedBox(height: 8),
            Text(
              isGasto ? '¿Cuánto gastaste?' : '¿Cuánto recibiste?',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    focusNode: _amountFocus,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      _CommaDotFormatter(),
                    ],
                    style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: accent),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(fontWeight: FontWeight.bold),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      final cleaned = v.replaceAll(',', '.');
                      setState(() => _amount = double.tryParse(cleaned) ?? 0);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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

  Widget _buildCategoryStep(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isGasto = _selectedType == TransactionType.gasto;
    final accent = isGasto ? cs.error : Colors.green;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goToStep(1),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Monto'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
            Text(isGasto ? '¿En qué categoría?' : '¿De dónde viene?',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((cat) {
                final sel = _selectedCategory == cat;
                return ActionChip(
                  onPressed: _saving ? null : () => setState(() => _selectedCategory = cat),
                  avatar: Icon(cat.icon, color: sel ? cat.color : null, size: 20),
                  label: Text(cat.label),
                  labelStyle: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: sel ? FontWeight.bold : null,
                    color: sel ? accent : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: sel ? BorderSide(color: accent, width: 2) : BorderSide.none,
                  ),
                  backgroundColor: sel ? accent.withValues(alpha: 0.08) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedCategory != null && !_saving ? () => _goToStep(3) : null,
                child: const Text('Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 3: Billetera ──

  Widget _buildAccountStep(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goToStep(2),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Categoría'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
            Text('¿Desde qué billetera?',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _accounts.map((acc) {
                return ActionChip(
                  onPressed: _saving ? null : () {
                    if (_showCommentStep) {
                      setState(() => _pendingAccount = acc);
                      _goToStep(4);
                    } else {
                      _save(acc);
                    }
                  },
                  avatar: CircleAvatar(backgroundColor: acc.color, radius: 12, child: const SizedBox.shrink()),
                  label: Text(acc.name),
                  labelStyle: theme.textTheme.bodyLarge,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 4: Comentario ──

  Widget _buildCommentStep(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goToStep(3),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Billetera'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
            Text('¿Algún comentario?',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('Opcional — podés dejarlo vacío',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 200,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: almuerzo con el equipo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () {
                  if (_pendingAccount != null) _save(_pendingAccount!);
                },
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_selectedType == TransactionType.gasto ? 'Registrar gasto' : 'Registrar ingreso'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommaDotFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(',', '.');
    if (text.split('.').length > 2) return oldValue;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}