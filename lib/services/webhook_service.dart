/// Servicio que dispara un webhook HTTP POST al registrar.
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
      'type': expense.type.name,
      'category': expense.category.name,
      'account': expense.account.toJson(),
      'date': expense.date.toIso8601String(),
      if (expense.comment.isNotEmpty) 'comment': expense.comment,
      'app': 'AppGastos',
      'version': 1,
    };

    try {
      await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'AppGastos/1.0',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fire-and-forget.
    }
  }
}
