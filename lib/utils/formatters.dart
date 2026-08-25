/// Utilidades de formato de moneda.
library;

import 'package:intl/intl.dart';

/// Formatea un monto como moneda.
///
/// Por defecto usa peso colombiano (COP) sin decimales porque es lo más
/// común en el mercado hispanohablante donde se enmarca esta app,
/// pero es trivialmente cambiable pasando otra [locale] o [symbol].
String formatCurrency(double amount, {String locale = 'es_CO', String symbol = '\$'}) {
  final formatter = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 0);
  return formatter.format(amount);
}

/// Formatea una fecha como "dd/MM/yyyy HH:mm".
String formatDateTime(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy HH:mm');
  return formatter.format(date);
}
