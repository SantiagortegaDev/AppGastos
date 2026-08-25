/// Ítem de la lista de registros.
library;

import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/app_settings.dart';
import '../utils/formatters.dart';

class ExpenseListItem extends StatelessWidget {
  final Expense expense;
  final CurrencyInfo? currency;
  const ExpenseListItem({super.key, required this.expense, this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGasto = expense.type == TransactionType.gasto;
    final amountColor = isGasto ? theme.colorScheme.error : Colors.green;
    final prefix = isGasto ? '-' : '+';
    final catColor = expense.category.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icono de categoría.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(expense.category.icon, color: catColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Info.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(expense.category.label, style: theme.textTheme.titleSmall),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: expense.account.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(height: 2),
                    Text(
                      expense.comment.isNotEmpty ? '${formatDateTime(expense.date)} · ${expense.comment}' : formatDateTime(expense.date),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Monto.
              Text(
                '$prefix${formatCurrency(expense.amount, currency: currency)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}