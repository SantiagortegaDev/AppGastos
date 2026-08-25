/// Repositorio de registros con persistencia en `shared_preferences`.
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
    _loadFromDisk();
  }

  void _loadFromDisk() {
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

  Future<void> reload() async {
    await _prefs.reload();
    _expenses.clear();
    _loadFromDisk();
  }

  List<Expense> get all {
    final sorted = [..._expenses]..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  double get totalExpenses =>
      _expenses
          .where((e) => e.type == TransactionType.gasto)
          .fold(0.0, (sum, e) => sum + e.amount);

  double get totalIncome =>
      _expenses
          .where((e) => e.type == TransactionType.ingreso)
          .fold(0.0, (sum, e) => sum + e.amount);

  double get balance => totalIncome - totalExpenses;

  int get count => _expenses.length;

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
