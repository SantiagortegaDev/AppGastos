/// Configuración global de la app.
///
/// Incluye:
/// - [themeMode]: claro / oscuro / sistema.
/// - [seedColor]: color semilla para el ColorScheme de Material 3.
/// - [accounts]: lista de cuentas configuradas por el usuario.
/// - [defaultAccountId]: cuenta seleccionada por defecto en el flujo de captura.
/// - [webhookUrl]: URL donde se envía un POST al registrar un gasto (vacío = desactivado).
library;

import 'package:flutter/material.dart';

import 'account.dart';

enum AppThemeMode { system, light, dark }

class AppSettings {
  final AppThemeMode themeMode;
  final Color seedColor;
  final List<Account> accounts;
  final String defaultAccountId;
  final String webhookUrl;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.seedColor = const Color(0xFF16A34A),
    this.accounts = kDefaultAccounts,
    this.defaultAccountId = 'acc-cash',
    this.webhookUrl = '',
  });

  Account get defaultAccount =>
      accounts.firstWhere((a) => a.id == defaultAccountId,
          orElse: () => accounts.isNotEmpty ? accounts.first : kDefaultAccounts.first);

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.system: return ThemeMode.system;
      case AppThemeMode.light: return ThemeMode.light;
      case AppThemeMode.dark: return ThemeMode.dark;
    }
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    Color? seedColor,
    List<Account>? accounts,
    String? defaultAccountId,
    String? webhookUrl,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    seedColor: seedColor ?? this.seedColor,
    accounts: accounts ?? this.accounts,
    defaultAccountId: defaultAccountId ?? this.defaultAccountId,
    webhookUrl: webhookUrl ?? this.webhookUrl,
  );
}

/// Paletas predefinidas para que el usuario elija en Settings.
class ColorPalette {
  final String name;
  final Color color;
  const ColorPalette(this.name, this.color);
}

const List<ColorPalette> kColorPalettes = [
  ColorPalette('Verde', Color(0xFF16A34A)),
  ColorPalette('Azul', Color(0xFF2563EB)),
  ColorPalette('Púrpura', Color(0xFF9333EA)),
  ColorPalette('Rosa', Color(0xFFDB2777)),
  ColorPalette('Naranja', Color(0xFFEA580C)),
  ColorPalette('Rojo', Color(0xFFDC2626)),
  ColorPalette('Teal', Color(0xFF0D9488)),
  ColorPalette('Índigo', Color(0xFF4F46E5)),
];
