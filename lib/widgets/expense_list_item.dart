/// Ítem de la lista de registros (gastos e ingresos).
library;

import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../utils/formatters.dart';

class ExpenseListItem extends StatelessWidget {
  final Expense expense;
  const ExpenseListItem({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGasto = expense.type == TransactionType.gasto;
    final amountColor = isGasto ? colorScheme.error : Colors.green;
    final prefix = isGasto ? '-' : '+';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: expense.account.color.withValues(alpha: 0.15),
          child: Icon(expense.category.icon, color: expense.account.color),
        ),
        title: Row(
          children: [
            Text(expense.category.label,
                style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: expense.account.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                expense.account.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: expense.account.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDateTime(expense.date)),
            if (expense.comment.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                expense.comment,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Text(
          '$prefix${formatCurrency(expense.amount)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
      ),
    );
  }
}
