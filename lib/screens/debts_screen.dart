/// Pantalla de deudas: lo que me deben y lo que yo debo.
library;

import 'package:flutter/material.dart';
import '../models/currency.dart';
import '../models/debt.dart';
import '../services/debt_repository.dart';
import '../utils/formatters.dart';

class DebtsScreen extends StatefulWidget {
  final DebtRepository repository;
  final CurrencyInfo currency;
  const DebtsScreen({super.key, required this.repository, required this.currency});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final debts = widget.repository.all;
        return Scaffold(
          appBar: AppBar(title: const Text('Deudas')),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildSummary(theme, cs)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (debts.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmpty(theme))
              else
                SliverList.builder(
                  itemCount: debts.length,
                  itemBuilder: (_, i) => _DebtTile(
                    debt: debts[i],
                    currency: widget.currency,
                    onTap: () => _showDebtOptions(debts[i]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addDebt,
            icon: const Icon(Icons.add),
            label: const Text('Nueva deuda'),
          ),
        );
      },
    );
  }

  Widget _buildSummary(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              theme, cs,
              label: 'Me deben',
              amount: widget.repository.totalOwedToMe,
              color: Colors.green,
              icon: Icons.call_received_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryCard(
              theme, cs,
              label: 'Yo debo',
              amount: widget.repository.totalIOwe,
              color: cs.error,
              icon: Icons.call_made_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(ThemeData theme, ColorScheme cs,
      {required String label, required double amount, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: cs.outline)),
          const SizedBox(height: 2),
          Text(formatCurrency(amount, currency: widget.currency),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ],
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
            Icon(Icons.handshake_outlined, size: 72, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Sin deudas registradas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Tocá "Nueva deuda" para anotar algo que te deben o que debés.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Future<void> _addDebt() async {
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DebtDirection direction = DebtDirection.owedToMe;
    DateTime? dueDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nueva deuda', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SegmentedButton<DebtDirection>(
                segments: const [
                  ButtonSegment(value: DebtDirection.owedToMe, label: Text('Me deben'), icon: Icon(Icons.call_received_rounded)),
                  ButtonSegment(value: DebtDirection.iOwe, label: Text('Yo debo'), icon: Icon(Icons.call_made_rounded)),
                ],
                selected: {direction},
                onSelectionChanged: (sel) => setSt(() => direction = sel.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: personCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Persona', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(dueDate == null ? 'Sin fecha límite' : 'Vence: ${formatDateShort(dueDate!)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) setSt(() => dueDate = picked);
                },
              ),
              const SizedBox(height: 4),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Nota (opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_note_outlined)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final person = personCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
                    if (person.isEmpty || amount <= 0) return;
                    widget.repository.add(Debt.create(
                      person: person,
                      amount: amount,
                      direction: direction,
                      dueDate: dueDate,
                      note: noteCtrl.text.trim(),
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDebtOptions(Debt debt) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(debt.person, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${debt.direction.label} · Restante: ${formatCurrency(debt.remaining, currency: widget.currency)}'),
            ),
            if (!debt.isSettled)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Registrar pago / marcar saldada'),
                onTap: () {
                  Navigator.pop(ctx);
                  _registerPayment(debt);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () {
                widget.repository.remove(debt.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerPayment(Debt debt) async {
    final amountCtrl = TextEditingController(text: debt.remaining.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar pago'),
        content: TextField(
          controller: amountCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto pagado', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
              if (amount <= 0) return;
              widget.repository.registerPayment(debt.id, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  final Debt debt;
  final CurrencyInfo currency;
  final VoidCallback onTap;
  const _DebtTile({required this.debt, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isOwedToMe = debt.direction == DebtDirection.owedToMe;
    final color = debt.isSettled ? cs.outline : (isOwedToMe ? Colors.green : cs.error);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(isOwedToMe ? Icons.call_received_rounded : Icons.call_made_rounded, color: color),
          ),
          title: Text(debt.person, style: TextStyle(decoration: debt.isSettled ? TextDecoration.lineThrough : null)),
          subtitle: Text(
            debt.dueDate != null
                ? '${debt.direction.label} · Vence ${formatDateShort(debt.dueDate!)}'
                : debt.direction.label,
            style: TextStyle(color: debt.isOverdue ? cs.error : null),
          ),
          trailing: Text(
            debt.isSettled ? 'Saldada' : formatCurrency(debt.remaining, currency: currency),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ),
    );
  }
}
