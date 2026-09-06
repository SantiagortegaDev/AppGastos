/// Repositorio de deudas (persistido con shared_preferences, igual que
/// ExpenseRepository).
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/debt.dart';

class DebtRepository extends ChangeNotifier {
  static const String _storageKey = 'appgastos.debts.v1';
  late final SharedPreferences _prefs;
  final List<Debt> _debts = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromDisk();
  }

  void _loadFromDisk() {
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _debts.addAll(decoded.map((d) => Debt.fromJson(d as Map<String, dynamic>)));
      } catch (_) {}
    }
  }

  List<Debt> get all {
    final sorted = [..._debts]..sort((a, b) {
        if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
        final ad = a.dueDate;
        final bd = b.dueDate;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return List.unmodifiable(sorted);
  }

  double get totalOwedToMe => _debts
      .where((d) => d.direction == DebtDirection.owedToMe)
      .fold(0.0, (s, d) => s + d.remaining);

  double get totalIOwe => _debts
      .where((d) => d.direction == DebtDirection.iOwe)
      .fold(0.0, (s, d) => s + d.remaining);

  Future<void> add(Debt debt) async {
    _debts.add(debt);
    await _persist();
  }

  Future<void> registerPayment(String id, double amount) async {
    final i = _debts.indexWhere((d) => d.id == id);
    if (i == -1) return;
    final d = _debts[i];
    _debts[i] = d.copyWith(paidAmount: (d.paidAmount + amount).clamp(0, d.amount));
    await _persist();
  }

  Future<void> remove(String id) async {
    _debts.removeWhere((d) => d.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_storageKey, jsonEncode(_debts.map((d) => d.toJson()).toList()));
    notifyListeners();
  }
}
