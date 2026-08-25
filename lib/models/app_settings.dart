/// Configuración global de la app.
library;

import 'package:flutter/material.dart';
import 'account.dart';
import 'budget.dart';
import 'currency.dart';

enum AppThemeMode { system, light, dark }

const List<Account> kDefaultAccounts = [
  Account(id: 'acc-cash', name: 'Efectivo', colorValue: 0xFF22C55E, balance: 0.0),
  Account(id: 'acc-bank', name: 'Banco', colorValue: 0xFF3B82F6, balance: 0.0),
  Account(id: 'acc-card', name: 'Tarjeta', colorValue: 0xFFA855F7, balance: 0.0),
];

const List<ColorPalette> kColorPalettes = [
  ColorPalette('Verde', Color(0xFF22C55E)),
  ColorPalette('Azul', Color(0xFF3B82F6)),
  ColorPalette('Púrpura', Color(0xFFA855F7)),
  ColorPalette('Rosa', Color(0xFFEC4899)),
  ColorPalette('Naranja', Color(0xFFF97316)),
  ColorPalette('Rojo', Color(0xFFEF4444)),
  ColorPalette('Teal', Color(0xFF14B8A6)),
  ColorPalette('Índigo', Color(0xFF6366F1)),
  ColorPalette('Cyan', Color(0xFF06B6D4)),
  ColorPalette('Ámbar', Color(0xFFF59E0B)),
  ColorPalette('Lima', Color(0xFF84CC16)),
  ColorPalette('Fucsia', Color(0xFFD946EF)),
];

class ColorPalette {
  final String name;
  final Color color;
  const ColorPalette(this.name, this.color);
}

class AppSettings {
  final AppThemeMode themeMode;
  final Color seedColor;
  final List<Account> accounts;
  final String defaultAccountId;
  final String webhookUrl;
  final bool askForComment;
  // Nuevas configuraciones
  final String currencyCode;
  final List<Budget> budgets;
  final bool biometricLock;
  final bool reminderEnabled;
  final int reminderDays;
  final String apiBaseUrl;
  final String apiToken;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.seedColor = const Color(0xFF22C55E),
    this.accounts = kDefaultAccounts,
    this.defaultAccountId = 'acc-cash',
    this.webhookUrl = '',
    this.askForComment = true,
    this.currencyCode = 'COP',
    this.budgets = const [],
    this.biometricLock = false,
    this.reminderEnabled = false,
    this.reminderDays = 3,
    this.apiBaseUrl = '',
    this.apiToken = '',
  });

  CurrencyInfo get currency =>
      kCurrencies.firstWhere((c) => c.code == currencyCode, orElse: () => kDefaultCurrency);

  Account get defaultAccount => accounts.firstWhere(
        (a) => a.id == defaultAccountId,
        orElse: () => accounts.isNotEmpty ? accounts.first : kDefaultAccounts.first,
      );

  ThemeMode get flutterThemeMode => switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  AppSettings copyWith({
    AppThemeMode? themeMode,
    Color? seedColor,
    List<Account>? accounts,
    String? defaultAccountId,
    String? webhookUrl,
    bool? askForComment,
    String? currencyCode,
    List<Budget>? budgets,
    bool? biometricLock,
    bool? reminderEnabled,
    int? reminderDays,
    String? apiBaseUrl,
    String? apiToken,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        seedColor: seedColor ?? this.seedColor,
        accounts: accounts ?? this.accounts,
        defaultAccountId: defaultAccountId ?? this.defaultAccountId,
        webhookUrl: webhookUrl ?? this.webhookUrl,
        askForComment: askForComment ?? this.askForComment,
        currencyCode: currencyCode ?? this.currencyCode,
        budgets: budgets ?? this.budgets,
        biometricLock: biometricLock ?? this.biometricLock,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderDays: reminderDays ?? this.reminderDays,
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
        apiToken: apiToken ?? this.apiToken,
      );
}