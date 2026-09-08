/// Escaneo de recibos: extrae texto con ML Kit y adivina el monto total.
library;

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/amount_text_parser.dart';

class ReceiptScanResult {
  final String rawText;
  final double? amount;
  final String? bestLine;
  const ReceiptScanResult({required this.rawText, this.amount, this.bestLine});
}

class ReceiptScannerService {
  Future<ReceiptScanResult> scanFromFile(File file) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFile(file);
      final result = await recognizer.processImage(input);
      final guess = guessAmount(result.text);
      return ReceiptScanResult(rawText: result.text, amount: guess.amount, bestLine: guess.bestLine);
    } finally {
      await recognizer.close();
    }
  }
}
