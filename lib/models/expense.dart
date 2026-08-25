/// Modelo de datos para un registro (gasto o ingreso).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'account.dart';

// ── Tipo de transacción ──

enum TransactionType {
  gasto('Gasto', Icons.arrow_downward),
  ingreso('Ingreso', Icons.arrow_upward);

  final String label;
  final IconData icon;
  const TransactionType(this.label, this.icon);

  static TransactionType fromName(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => TransactionType.gasto);
}

// ── Categorías ──

enum ExpenseCategory {
  // Gastos
  comida('Comida', Icons.restaurant, TransactionType.gasto),
  transporte('Transporte', Icons.directions_bus, TransactionType.gasto),
  compras('Compras', Icons.shopping_bag, TransactionType.gasto),
  servicios('Servicios', Icons.receipt_long, TransactionType.gasto),
  otro('Otro', Icons.category, TransactionType.gasto),
  // Ingresos
  salario('Salario', Icons.work, TransactionType.ingreso),
  venta('Venta', Icons.storefront, TransactionType.ingreso),
  regalo('Regalo', Icons.card_giftcard, TransactionType.ingreso),
  inversion('Inversión', Icons.trending_up, TransactionType.ingreso),
  otroIngreso('Otro ingreso', Icons.category, TransactionType.ingreso);

  final String label;
  final IconData icon;
  final TransactionType type;
  const ExpenseCategory(this.label, this.icon, this.type);

  static ExpenseCategory fromName(String name) =>
      values.firstWhere((c) => c.name == name, orElse: () => ExpenseCategory.otro);

  static List<ExpenseCategory> forType(TransactionType type) =>
      values.where((c) => c.type == type).toList();
}

// ── Registro (gasto / ingreso) ──

class Expense {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final Account account;
  final DateTime date;
  final TransactionType type;
  final String comment;

  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.account,
    required this.date,
    this.type = TransactionType.gasto,
    this.comment = '',
  });

  factory Expense.create({
    required double amount,
    required ExpenseCategory category,
    required Account account,
    TransactionType type = TransactionType.gasto,
    String comment = '',
    DateTime? date,
  }) {
    assert(amount > 0, 'El monto debe ser mayor a 0');
    return Expense(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 32)}',
      amount: amount,
      category: category,
      account: account,
      date: date ?? DateTime.now(),
      type: type,
      comment: comment,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category.name,
        'account': account.toJson(),
        'date': date.toIso8601String(),
        'type': type.name,
        if (comment.isNotEmpty) 'comment': comment,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategory.fromName(json['category'] as String),
        account: Account.fromJson(json['account'] as Map<String, dynamic>),
        date: DateTime.parse(json['date'] as String),
        type: json['type'] != null
            ? TransactionType.fromName(json['type'] as String)
            : TransactionType.gasto,
        comment: (json['comment'] as String?) ?? '',
      );
}

final _rng = math.Random();
