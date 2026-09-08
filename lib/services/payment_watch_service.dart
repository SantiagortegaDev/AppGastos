/// Persiste las reglas de detección de pagos. Guarda el JSON con la MISMA
/// clave que lee `PaymentNotificationListenerService` (Kotlin) directamente
/// del archivo nativo `FlutterSharedPreferences` (shared_preferences le
/// antepone el prefijo "flutter." a la clave automáticamente).
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_watch_rule.dart';

class PaymentWatchService extends ChangeNotifier {
  static const String _key = 'appgastos.paymentwatch.v1';

  late final SharedPreferences _prefs;
  List<PaymentWatchRule> _rules = [];
  List<PaymentWatchRule> get rules => List.unmodifiable(_rules);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _rules = decoded.map((r) => PaymentWatchRule.fromJson(r as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
  }

  Future<void> addRule(PaymentWatchRule rule) async {
    _rules = [..._rules, rule];
    await _persist();
  }

  Future<void> removeRule(String id) async {
    _rules = _rules.where((r) => r.id != id).toList();
    await _persist();
  }

  Future<void> setRuleEnabled(String id, bool enabled) async {
    _rules = _rules.map((r) => r.id == id ? r.copyWith(enabled: enabled) : r).toList();
    await _persist();
  }

  Future<void> _persist() async {
    // El listener nativo solo debe ver las reglas activas.
    final active = _rules.where((r) => r.enabled).map((r) => r.toJson()).toList();
    await _prefs.setString(_key, jsonEncode(active));
    notifyListeners();
  }
}
