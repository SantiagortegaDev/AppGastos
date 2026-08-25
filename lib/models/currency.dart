/// Información de monedas soportadas.
library;

import 'package:flutter/material.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String locale;
  final String name;
  final int decimals;
  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.name,
    required this.decimals,
  });
}

const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo(code: 'COP', symbol: r'$', locale: 'es_CO', name: 'Peso colombiano', decimals: 0),
  CurrencyInfo(code: 'MXN', symbol: r'$', locale: 'es_MX', name: 'Peso mexicano', decimals: 2),
  CurrencyInfo(code: 'ARS', symbol: r'$', locale: 'es_AR', name: 'Peso argentino', decimals: 0),
  CurrencyInfo(code: 'CLP', symbol: r'$', locale: 'es_CL', name: 'Peso chileno', decimals: 0),
  CurrencyInfo(code: 'PEN', symbol: r'S/.', locale: 'es_PE', name: 'Sol peruano', decimals: 2),
  CurrencyInfo(code: 'BRL', symbol: r'R$', locale: 'pt_BR', name: 'Real brasileño', decimals: 2),
  CurrencyInfo(code: 'USD', symbol: r'US$', locale: 'en_US', name: 'Dólar estadounidense', decimals: 2),
  CurrencyInfo(code: 'EUR', symbol: r'€', locale: 'de_DE', name: 'Euro', decimals: 2),
  CurrencyInfo(code: 'GBP', symbol: r'£', locale: 'en_GB', name: 'Libra esterlina', decimals: 2),
  CurrencyInfo(code: 'JPY', symbol: r'¥', locale: 'ja_JP', name: 'Yen japonés', decimals: 0),
  CurrencyInfo(code: 'CAD', symbol: r'C$', locale: 'en_CA', name: 'Dólar canadiense', decimals: 2),
  CurrencyInfo(code: 'UYU', symbol: r'$', locale: 'es_UY', name: 'Peso uruguayo', decimals: 0),
];

final CurrencyInfo kDefaultCurrency = kCurrencies[0]; // COP
