/// Servicio de configuración persistida.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/app_settings.dart';
import '../models/budget.dart';

class SettingsService extends ChangeNotifier {
  static const String _key = 'appgastos.settings.v2';

  late final SharedPreferences _prefs;
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _settings = AppSettings(
          themeMode: AppThemeMode.values.firstWhere(
            (m) => m.name == json['themeMode'],
            orElse: () => AppThemeMode.system,
          ),
          seedColor: Color((json['seedColor'] as num).toInt()),
          accounts: (json['accounts'] as List<dynamic>)
              .map((a) => Account.fromJson(a as Map<String, dynamic>))
              .toList(),
          defaultAccountId: json['defaultAccountId'] as String? ?? 'acc-cash',
          webhookUrl: json['webhookUrl'] as String? ?? '',
          askForComment: json['askForComment'] as bool? ?? true,
          currencyCode: json['currencyCode'] as String? ?? 'COP',
          budgets: (json['budgets'] as List<dynamic>?)
                  ?.map((b) => Budget.fromJson(b as Map<String, dynamic>))
                  .toList() ??
              [],
          biometricLock: json['biometricLock'] as bool? ?? false,
          reminderEnabled: json['reminderEnabled'] as bool? ?? false,
          reminderDays: json['reminderDays'] as int? ?? 3,
          apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
          apiToken: json['apiToken'] as String? ?? '',
        );
      } catch (_) {
        // JSON corrupto — defaults.
      }
    }
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _prefs.setString(_key, jsonEncode({
      'themeMode': _settings.themeMode.name,
      'seedColor': _settings.seedColor.value,
      'accounts': _settings.accounts.map((a) => a.toJson()).toList(),
      'defaultAccountId': _settings.defaultAccountId,
      'webhookUrl': _settings.webhookUrl,
      'askForComment': _settings.askForComment,
      'currencyCode': _settings.currencyCode,
      'budgets': _settings.budgets.map((b) => b.toJson()).toList(),
      'biometricLock': _settings.biometricLock,
      'reminderEnabled': _settings.reminderEnabled,
      'reminderDays': _settings.reminderDays,
      'apiBaseUrl': _settings.apiBaseUrl,
      'apiToken': _settings.apiToken,
    }));
  }

  Future<void> setThemeMode(AppThemeMode mode) => update(_settings.copyWith(themeMode: mode));
  Future<void> setSeedColor(Color color) => update(_settings.copyWith(seedColor: color));
  Future<void> setWebhookUrl(String url) => update(_settings.copyWith(webhookUrl: url));
  Future<void> setAskForComment(bool v) => update(_settings.copyWith(askForComment: v));
  Future<void> setCurrencyCode(String code) => update(_settings.copyWith(currencyCode: code));
  Future<void> setBiometricLock(bool v) => update(_settings.copyWith(biometricLock: v));
  Future<void> setReminderEnabled(bool v) => update(_settings.copyWith(reminderEnabled: v));
  Future<void> setReminderDays(int d) => update(_settings.copyWith(reminderDays: d));
  Future<void> setApiBaseUrl(String u) => update(_settings.copyWith(apiBaseUrl: u));
  Future<void> setApiToken(String t) => update(_settings.copyWith(apiToken: t));

  // ── Billeteras ──

  Future<void> addAccount(Account account) async {
    final next = [..._settings.accounts, account];
    String defaultId = _settings.defaultAccountId;
    if (next.length == 1) defaultId = account.id;
    await update(_settings.copyWith(accounts: next, defaultAccountId: defaultId));
  }

  Future<void> removeAccount(String id) async {
    final next = _settings.accounts.where((a) => a.id != id).toList();
    String defaultId = _settings.defaultAccountId;
    if (defaultId == id && next.isNotEmpty) defaultId = next.first.id;
    await update(_settings.copyWith(accounts: next, defaultAccountId: defaultId));
  }

  Future<void> setDefaultAccount(String id) => update(_settings.copyWith(defaultAccountId: id));

  Future<void> updateAccount(String id, {String? name, Color? color, double? balance}) async {
    final updated = _settings.accounts.map((a) {
      if (a.id != id) return a;
      return a.copyWith(name: name, colorValue: color?.value, balance: balance);
    }).toList();
    await update(_settings.copyWith(accounts: updated));
  }

  // ── Presupuestos ──

  Future<void> addBudget(Budget budget) async {
    await update(_settings.copyWith(budgets: [..._settings.budgets, budget]));
  }

  Future<void> removeBudget(String id) async {
    await update(_settings.copyWith(budgets: _settings.budgets.where((b) => b.id != id).toList()));
  }
}