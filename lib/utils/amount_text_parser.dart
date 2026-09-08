/// Heurística compartida para adivinar un monto dentro de un texto libre
/// (recibo escaneado por OCR o notificación de pago detectada).
library;

class AmountGuess {
  final double? amount;
  final String? bestLine;
  const AmountGuess({this.amount, this.bestLine});
}

final _numberPattern = RegExp(r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)');
final _totalKeywords = RegExp(
  r'\b(total|total a pagar|monto total|total pagar|gran total|importe|pago de|pago por|compra por|has pagado|realizaste un pago)\b',
  caseSensitive: false,
);

/// Adivina el monto más probable dentro de [text]: prioriza líneas con
/// palabras clave de pago/total; si no encuentra ninguna, usa el número
/// más grande de todo el texto.
AmountGuess guessAmount(String text) {
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return const AmountGuess();

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

  if (bestAmount == null) {
    for (final line in lines) {
      final amount = _biggestNumberIn(line);
      if (amount != null && (bestAmount == null || amount > bestAmount)) {
        bestAmount = amount;
        bestLine = line.trim();
      }
    }
  }

  return AmountGuess(amount: bestAmount, bestLine: bestLine);
}

double? _biggestNumberIn(String line) {
  double? max;
  for (final match in _numberPattern.allMatches(line)) {
    final parsed = parseLatinNumber(match.group(0)!);
    if (parsed != null && parsed > 0 && (max == null || parsed > max)) {
      max = parsed;
    }
  }
  return max;
}

/// Interpreta números con separador de miles "." o "," y decimales con el
/// otro símbolo (formato latinoamericano o anglosajón).
double? parseLatinNumber(String raw) {
  var s = raw.trim();
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma > lastDot) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (lastDot > lastComma) {
    s = s.replaceAll(',', '');
  } else {
    s = s.replaceAll(',', '').replaceAll('.', '');
  }
  return double.tryParse(s);
}
