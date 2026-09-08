/// Pantalla de verificación: se abre cuando se detecta un posible pago en
/// otra app. Muestra los datos como un recibo y el usuario confirma (o
/// descarta) antes de que se registre nada.
library;

import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../services/expense_repository.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../utils/amount_text_parser.dart';
import '../utils/formatters.dart';

class PaymentVerificationScreen extends StatefulWidget {
  final ExpenseRepository repository;
  final SettingsService settingsService;
  final String sourceLabel;
  final String rawText;

  const PaymentVerificationScreen({
    super.key,
    required this.repository,
    required this.settingsService,
    required this.sourceLabel,
    required this.rawText,
  });

  @override
  State<PaymentVerificationScreen> createState() => _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _commentCtrl;
  late ExpenseCategory _category;
  late Account _account;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.settingsService.settings;
    final guess = guessAmount(widget.rawText);
    _amountCtrl = TextEditingController(
      text: guess.amount != null ? guess.amount!.toStringAsFixed(0) : '',
    );
    _commentCtrl = TextEditingController(text: 'Pago detectado en ${widget.sourceLabel}');
    _category = ExpenseCategory.otro;
    _account = settings.defaultAccount;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0 || _saving) return;
    setState(() => _saving = true);

    final expense = Expense.create(
      amount: amount,
      category: _category,
      account: _account,
      type: TransactionType.gasto,
      comment: _commentCtrl.text.trim(),
    );
    await widget.repository.add(expense);
    await widget.settingsService.updateAccount(_account.id, balance: _account.balance - amount);
    await NotificationService.instance.scheduleRegisterReminder(
      enabled: widget.settingsService.settings.reminderEnabled,
      days: widget.settingsService.settings.reminderDays,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = widget.settingsService.settings;
    final categories = ExpenseCategory.forType(TransactionType.gasto);

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar pago detectado')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tarjeta estilo recibo ──
          Card(
            elevation: 0,
            color: cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Detectado en ${widget.sourceLabel}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _DashedDivider(),
                  const SizedBox(height: 16),
                  Text('MONTO', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.error),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: '0', contentPadding: EdgeInsets.zero),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  const _DashedDivider(),
                  const SizedBox(height: 12),
                  Text('TEXTO ORIGINAL DE LA NOTIFICACIÓN',
                      style: theme.textTheme.labelSmall?.copyWith(color: cs.outline, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(widget.rawText, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Categoría ──
          Text('Categoría', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: categories.map((cat) {
              final sel = _category == cat;
              return ChoiceChip(
                selected: sel,
                onSelected: (_) => setState(() => _category = cat),
                avatar: Icon(cat.icon, size: 18, color: sel ? cat.color : null),
                label: Text(cat.label),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Billetera ──
          Text('Billetera', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: settings.accounts.map((acc) {
              final sel = _account.id == acc.id;
              return ChoiceChip(
                selected: sel,
                onSelected: (_) => setState(() => _account = acc),
                avatar: CircleAvatar(backgroundColor: acc.color, radius: 8, child: const SizedBox.shrink()),
                label: Text(acc.name),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Comentario', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_note_outlined)),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('No es un gasto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _confirm,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Guardando…' : 'Registrar ${formatCurrency(double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0, currency: settings.currency)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 6.0;
      const spacing = 4.0;
      final count = (constraints.maxWidth / (dashWidth + spacing)).floor();
      return Row(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.only(right: spacing),
            child: Container(width: dashWidth, height: 1.5, color: color),
          ),
        ),
      );
    });
  }
}
