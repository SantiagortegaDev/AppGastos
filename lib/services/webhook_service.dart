/// Servicio que dispara un webhook HTTP POST al registrar un gasto.
///
/// Formato del payload JSON:
/// ```json
/// {
///   "event": "expense.created",
///   "id": "1712345678-12345",
///   "amount": 15000.0,
///   "category": "comida",
///   "account": { "id": "acc-cash", "name": "Efectivo", "color": 4283349034 },
///   "date": "2025-01-30T12:34:56.789Z",
///   "app": "AppGastos",
///   "version": 1
/// }
/// ```
///
/// Se ejecuta en background (no bloquea la UI). Reintentos: 1, con timeout 5s.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/expense.dart';

class WebhookService {
  static Future<void> fireIfConfigured({
    required String? webhookUrl,
    required Expense expense,
  }) async {
    final url = webhookUrl?.trim();
    if (url == null || url.isEmpty) return;

    final payload = {
      'event': 'expense.created',
      'id': expense.id,
      'amount': expense.amount,
      'category': expense.category.name,
      'account': expense.account.toJson(),
      'date': expense.date.toIso8601String(),
      'app': 'AppGastos',
      'version': 1,
    };

    try {
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'AppGastos/1.0',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fire-and-forget: si falla, no bloqueamos el registro del gasto.
      // En una versión futura se puede agregar una cola de reintentos.
    }
  }
}
