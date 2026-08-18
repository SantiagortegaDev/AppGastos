/// Modelo de datos para un gasto registrado.
///
/// Cada gasto contiene:
/// - [amount]: monto numérico (siempre positivo).
/// - [category]: categoría predefinida (ver [ExpenseCategory]).
/// - [account]: cuenta desde la que se hizo el gasto (efectivo, banco, etc.).
/// - [date]: momento en el que se registró.
/// - [id]: identificador único.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'account.dart';

/// Categorías soportadas por la app.
enum ExpenseCategory {
  comida('Comida', Icons.restaurant),
  transporte('Transporte', Icons.directions_bus),
  compras('Compras', Icons.shopping_bag),
  servicios('Servicios', Icons.receipt_long),
  otro('Otro', Icons.category);

  final String label;
  final IconData icon;
  const ExpenseCategory(this.label, this.icon);

  static ExpenseCategory fromName(String name) =>
      values.firstWhere((c) => c.name == name, orElse: () => ExpenseCategory.otro);
}

class Expense {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final Account account;
  final DateTime date;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.account,
    required this.date,
  });

  factory Expense.create({
    required double amount,
    required ExpenseCategory category,
    required Account account,
    DateTime? date,
  }) {
    assert(amount > 0, 'El monto debe ser mayor a 0');
    return Expense(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 32)}',
      amount: amount,
      category: category,
      account: account,
      date: date ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category.name,
        'account': account.toJson(),
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategory.fromName(json['category'] as String),
        account: Account.fromJson(json['account'] as Map<String, dynamic>),
        date: DateTime.parse(json['date'] as String),
      );
}

final _rng = math.Random();
