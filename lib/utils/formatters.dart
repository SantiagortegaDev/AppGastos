/// Utilidades de formato.
library;

import 'package:intl/intl.dart';
import '../models/currency.dart';

/// Formatea un monto usando la moneda configurada.
String formatCurrency(double amount, {CurrencyInfo? currency}) {
  final c = currency ?? kDefaultCurrency;
  final formatter = NumberFormat.currency(
    locale: c.locale,
    symbol: c.symbol,
    decimalDigits: c.decimals,
  );
  return formatter.format(amount);
}

/// Formatea una fecha como "dd/MM/yyyy HH:mm".
String formatDateTime(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy HH:mm');
  return formatter.format(date);
}

/// Formatea una fecha corta.
String formatDateShort(DateTime date) {
  final formatter = DateFormat('dd/MM');
  return formatter.format(date);
}