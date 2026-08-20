/// Servicio de configuración persistida.
///
/// Expone un [ChangeNotifier] para que la UI reaccione a cambios
/// de tema, color, cuentas, webhook, etc.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/app_settings.dart';

class SettingsService extends ChangeNotifier {
  static const String _key = 'appgastos.settings.v1';

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
        );
      } catch (_) {
        // JSON corrupto — usamos defaults.
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
    }));
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      update(_settings.copyWith(themeMode: mode));

  Future<void> setSeedColor(Color color) =>
      update(_settings.copyWith(seedColor: color));

  Future<void> setWebhookUrl(String url) =>
      update(_settings.copyWith(webhookUrl: url));

  Future<void> addAccount(Account account) async {
    final next = [..._settings.accounts, account];
    String defaultId = _settings.defaultAccountId;
    if (next.length == 1) defaultId = account.id;
    await update(_settings.copyWith(
      accounts: next,
      defaultAccountId: defaultId,
    ));
  }

  Future<void> removeAccount(String id) async {
    final next = _settings.accounts.where((a) => a.id != id).toList();
    String defaultId = _settings.defaultAccountId;
    if (defaultId == id && next.isNotEmpty) defaultId = next.first.id;
    await update(_settings.copyWith(
      accounts: next,
      defaultAccountId: defaultId,
    ));
  }

  Future<void> setDefaultAccount(String id) =>
      update(_settings.copyWith(defaultAccountId: id));
}
