/// Repositorio de gastos con persistencia en `shared_preferences`.
///
/// Usa la misma key (`appgastos.expenses.v1`) que el overlay nativo Kotlin,
/// de manera que los gastos registrados desde el overlay aparezcan al
/// abrir la app sin necesidad de MethodChannel.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';

class ExpenseRepository {
  static const String _storageKey = 'appgastos.expenses.v1';

  late final SharedPreferences _prefs;
  final List<Expense> _expenses = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _expenses.addAll(
          decoded.map((e) => Expense.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {
        // JSON corrupto (raro pero posible si se editó a mano): ignoramos.
      }
    }
  }

  /// Recarga desde disco — útil cuando el overlay nativo pudo haber
  /// agregado un gasto mientras la app estaba en background.
  Future<void> reload() async {
    await _prefs.reload();
    _expenses.clear();
    final String? raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _expenses.addAll(
          decoded.map((e) => Expense.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {}
    }
  }

  List<Expense> get all {
    final sorted = [..._expenses]..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  double get total => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  Future<void> add(Expense expense) async {
    _expenses.add(expense);
    await _persist();
  }

  Future<void> remove(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_expenses.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
