/// Escaneo de recibos: extrae texto con ML Kit y adivina el monto total.
library;

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptScanResult {
  final String rawText;
  final double? amount;
  final String? bestLine;
  const ReceiptScanResult({required this.rawText, this.amount, this.bestLine});
}

class ReceiptScannerService {
  static final _numberPattern = RegExp(r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)');
  static final _totalKeywords = RegExp(
    r'\b(total|total a pagar|monto total|total pagar|gran total|importe)\b',
    caseSensitive: false,
  );

  Future<ReceiptScanResult> scanFromFile(File file) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFile(file);
      final result = await recognizer.processImage(input);
      return _parse(result.text);
    } finally {
      await recognizer.close();
    }
  }

  ReceiptScanResult _parse(String rawText) {
    final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // 1) Preferir una línea que contenga una palabra clave de "total".
    double? bestAmount;
    String? bestLine;
    for (final line in lines) {
      if (_totalKeywords.hasMatch(line)) {
        final amount = _biggestNumberIn(line);
        if (amount != null && (bestAmount == null || amount > bestAmount)) {
          bestAmount = amount;
          bestLine = line.trim();
        }
      }
    }

    // 2) Si no hay ninguna línea con "total", usar el número más grande
    //    de todo el recibo (heurística: el total suele ser el mayor monto).
    if (bestAmount == null) {
      for (final line in lines) {
        final amount = _biggestNumberIn(line);
        if (amount != null && (bestAmount == null || amount > bestAmount)) {
          bestAmount = amount;
          bestLine = line.trim();
        }
      }
    }

    return ReceiptScanResult(rawText: rawText, amount: bestAmount, bestLine: bestLine);
  }

  double? _biggestNumberIn(String line) {
    double? max;
    for (final match in _numberPattern.allMatches(line)) {
      final parsed = _parseNumber(match.group(0)!);
      if (parsed != null && parsed > 0 && (max == null || parsed > max)) {
        max = parsed;
      }
    }
    return max;
  }

  /// Interpreta números con separador de miles "." o "," y decimales con
  /// el otro símbolo (formato latinoamericano o anglosajón).
  double? _parseNumber(String raw) {
    var s = raw.trim();
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      // Coma = decimal, punto = miles.
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma) {
      // Punto = decimal, coma = miles.
      s = s.replaceAll(',', '');
    } else {
      s = s.replaceAll(',', '').replaceAll('.', '');
    }
    return double.tryParse(s);
  }
}
