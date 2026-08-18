/// Ítem de la lista de gastos. Card Material 3 con ícono de categoría,
/// fecha relativa y monto alineado a la derecha.
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Icon(expense.category.icon),
        ),
        title: Text(
          expense.category.label,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(formatDateTime(expense.date)),
        trailing: Text(
          formatCurrency(expense.amount),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.error,
          ),
        ),
      ),
    );
  }
}
