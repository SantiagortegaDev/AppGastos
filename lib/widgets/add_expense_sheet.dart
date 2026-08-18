/// Bottom sheet Material de 2 pasos para registrar un gasto.
///
/// Paso 1: Monto.
///   - TextField con keyboard numérico decimal, autofocus.
///   - Formatea el valor como moneda mientras el usuario escribe.
///   - Botón "Siguiente" habilitado solo si el monto es > 0.
///
/// Paso 2: Categoría.
///   - Grid de chips con ícono + label.
///   - Al tocar una categoría, se persiste el gasto y se cierra el sheet.
///
/// Manejo del teclado:
///   - `showModalBottomSheet(isScrollControlled: true)` + `Padding(viewInsets.bottom)`.
///   - Esto hace que el sheet suba correctamente cuando aparece el teclado.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
import '../services/expense_repository.dart';
import '../utils/formatters.dart';

class AddExpenseSheet extends StatefulWidget {
  final ExpenseRepository repository;
  const AddExpenseSheet({super.key, required this.repository});

  /// Abre el sheet. Devuelve `true` si se registró un gasto.
  static Future<bool> show(BuildContext context, ExpenseRepository repository) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddExpenseSheet(repository: repository),
    );
    return result ?? false;
  }

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  int _step = 1; // 1 = monto, 2 = categoría
  final TextEditingController _amountCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  String? _errorText;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  /// Devuelve el valor numérico actualmente escrito o `null` si inválido.
  double? _parsedAmount() {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  /// Avanza al paso 2 si el monto es válido.
  void _goNext() {
    final value = _parsedAmount();
    if (value == null || value <= 0) {
      setState(() => _errorText = 'Ingresa un monto mayor a 0');
      return;
    }
    setState(() {
      _errorText = null;
      _step = 2;
    });
    // Quitamos foco del TextField para que el teclado numérico se oculte
    // y queden visibles todos los chips de categoría.
    _amountFocus.unfocus();
  }

  Future<void> _save(ExpenseCategory category) async {
    if (_saving) return;
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);

    final expense = Expense.create(amount: amount, category: category);
    await widget.repository.add(expense);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // `viewInsets.bottom` = altura del teclado. Permite que el sheet
    // se desplace hacia arriba manteniendo el contenido visible.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  // ───────────────── Paso 1: Monto ─────────────────
  Widget _buildStep1() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle visual.
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          '¿Cuánto gastaste?',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _amountCtrl,
          focusNode: _amountFocus,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            // Permite dígitos y un punto decimal.
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _goNext(),
          decoration: InputDecoration(
            prefixText: '\$ ',
            hintText: '0',
            errorText: _errorText,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 18,
            ),
          ),
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _goNext,
          icon: const Text('Siguiente'),
          label: const Icon(Icons.arrow_forward),
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

  // ───────────────── Paso 2: Categoría ─────────────────
  Widget _buildStep2() {
    final theme = Theme.of(context);
    final amount = _parsedAmount() ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Recordatorio del monto ingresado en el paso 1.
        Text(
          'Gasto a registrar',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          formatCurrency(amount),
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          '¿En qué categoría?',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: ExpenseCategory.values.map((cat) {
            return _CategoryChip(
              category: cat,
              onTap: () => _save(cat),
              enabled: !_saving,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Botón para volver al paso 1.
        TextButton.icon(
          onPressed: _saving ? null : () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Cambiar monto'),
        ),
      ],
    );
  }
}

/// Chip de categoría reutilizable.
class _CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final VoidCallback onTap;
  final bool enabled;
  const _CategoryChip({
    required this.category,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: enabled ? onTap : null,
      avatar: Icon(category.icon),
      label: Text(category.label),
      labelStyle: theme.textTheme.titleMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
