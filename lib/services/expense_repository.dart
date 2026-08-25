/// Repositorio de registros con filtros.
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
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _expenses.addAll(decoded.map((e) => Expense.fromJson(e as Map<String, dynamic>)));
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

  double get totalExpenses => _expenses.where((e) => e.type == TransactionType.gasto).fold(0.0, (s, e) => s + e.amount);
  double get totalIncome => _expenses.where((e) => e.type == TransactionType.ingreso).fold(0.0, (s, e) => s + e.amount);
  double get balance => totalIncome - totalExpenses;
  int get count => _expenses.length;

  /// Filtrar registros con opciones.
  List<Expense> filter({
    String? query,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    DateTime? from,
    DateTime? to,
  }) {
    var list = all;
    if (type != null) list = list.where((e) => e.type == type).toList();
    if (categoryId != null) list = list.where((e) => e.category.name == categoryId).toList();
    if (accountId != null) list = list.where((e) => e.account.id == accountId).toList();
    if (from != null) list = list.where((e) => e.date.isAfter(from)).toList();
    if (to != null) list = list.where((e) => e.date.isBefore(to)).toList();
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((e) =>
        e.comment.toLowerCase().contains(q) ||
        e.category.label.toLowerCase().contains(q) ||
        e.account.name.toLowerCase().contains(q) ||
        e.amount.toString().contains(q)).toList();
    }
    return list;
  }

  /// Registros agrupados por fecha (para gráficos).
  Map<String, double> dailyTotals({DateTime? from, DateTime? to, TransactionType? type}) {
    var list = _expenses;
    if (type != null) list = list.where((e) => e.type == type).toList();
    if (from != null) list = list.where((e) => e.date.isAfter(from)).toList();
    if (to != null) list = list.where((e) => e.date.isBefore(to)).toList();
    final map = <String, double>{};
    for (final e in list) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }

  /// Totales por categoría.
  Map<String, double> categoryTotals({TransactionType? type, DateTime? from, DateTime? to}) {
    var list = _expenses;
    if (type != null) list = list.where((e) => e.type == type).toList();
    if (from != null) list = list.where((e) => e.date.isAfter(from)).toList();
    if (to != null) list = list.where((e) => e.date.isBefore(to)).toList();
    final map = <String, double>{};
    for (final e in list) {
      map[e.category.name] = (map[e.category.name] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> add(Expense expense) async {
    _expenses.add(expense);
    await _persist();
  }

  Future<void> remove(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_storageKey, jsonEncode(_expenses.map((e) => e.toJson()).toList()));
  }
}