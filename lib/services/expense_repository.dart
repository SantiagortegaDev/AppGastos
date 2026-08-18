/// Repositorio de gastos con persistencia local en `shared_preferences`.
///
/// Elección: `shared_preferences` sobre `sqflite` porque:
/// 1. Es la opción más simple (sin migraciones, sin esquema SQL).
/// 2. Suficiente para el volumen esperado de gastos de un usuario individual
///    (cientos / pocos miles de registros).
/// 3. Serializamos la lista completa a JSON — simple y robusto.
///
/// Si en el futuro se requieren filtros complejos, migración a `sqflite` o
/// `drift` sería trivial manteniendo este mismo modelo `Expense`.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';

class ExpenseRepository {
  static const String _storageKey = 'appgastos.expenses.v1';

  late final SharedPreferences _prefs;
  final List<Expense> _expenses = [];

  /// Inicializa el repositorio cargando los gastos persistidos.
  /// Debe llamarse una sola vez antes de usar el repositorio (ver [main]).
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _expenses.addAll(
        decoded.map((e) => Expense.fromJson(e as Map<String, dynamic>)),
      );
    }
  }

  /// Lista inmutable de gastos ordenados del más reciente al más antiguo.
  List<Expense> get all {
    final sorted = [..._expenses]
      ..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  /// Suma de todos los montos. Se calcula en O(n) — para miles de registros
  /// es trivial; si crece, se puede cachear.
  double get total => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Agrega un gasto y persiste inmediatamente.
  Future<void> add(Expense expense) async {
    _expenses.add(expense);
    await _persist();
  }

  /// Elimina un gasto por ID (útil para futuras features tipo swipe-to-delete).
  Future<void> remove(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_expenses.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
