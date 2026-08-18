/// Modelo de datos para un gasto registrado.
///
/// Cada gasto contiene:
/// - [amount]: monto numérico (siempre positivo).
/// - [category]: categoría predefinida (ver [ExpenseCategory]).
/// - [date]: momento en el que se registró.
/// - [id]: identificador único (generado con timestamp + random).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Categorías soportadas por la app.
///
/// Cada categoría expone un [label] legible y un [icon] Material.
/// Usar un `enum` (en vez de `String`) evita errores de tipeo y
/// simplifica la serialización/deserialización.
enum ExpenseCategory {
  comida('Comida', Icons.restaurant),
  transporte('Transporte', Icons.directions_bus),
  compras('Compras', Icons.shopping_bag),
  servicios('Servicios', Icons.receipt_long),
  otro('Otro', Icons.category);

  final String label;
  final IconData icon;
  const ExpenseCategory(this.label, this.icon);

  /// Helper para deserializar desde JSON de forma segura.
  static ExpenseCategory fromName(String name) =>
      values.firstWhere((c) => c.name == name, orElse: () => ExpenseCategory.otro);
}

class Expense {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
  });

  /// Crea un gasto con ID y fecha autogenerados (caso típico de la app).
  factory Expense.create({
    required double amount,
    required ExpenseCategory category,
    DateTime? date,
  }) {
    assert(amount > 0, 'El monto debe ser mayor a 0');
    return Expense(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 32)}',
      amount: amount,
      category: category,
      date: date ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category.name,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategory.fromName(json['category'] as String),
        date: DateTime.parse(json['date'] as String),
      );
}

// Generador de números pseudoaleatorios para evitar colisiones de ID
// cuando el usuario registra varios gastos en el mismo microsegundo.
final _rng = math.Random();
