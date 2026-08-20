/// Puente entre el `TileService` nativo (Kotlin) y Flutter.
///
/// Flujo:
/// 1. El usuario toca el Tile en el panel de ajustes rápidos.
/// 2. `ExpenseTileService.kt` lanza `MainActivity` con tema transparente
///    y el extra `open_expense_sheet = true`.
/// 3. `MainActivity.kt` reenvía ese evento a través de este canal.
/// 4. Flutter muestra el bottom sheet de captura con fondo transparente
///    y cierra la app al terminar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Nombre del canal — DEBE coincidir con el usado en `MainActivity.kt`.
const String _kChannelName = 'appgastos.dev/tile';

/// Acción que el Tile envía al abrir la app.
const String _kOpenExpenseSheet = 'openExpenseSheet';

/// Llave del intent extra en Kotlin.
const String kExtraOpenExpenseSheet = 'open_expense_sheet';

class TileChannel extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel(_kChannelName);

  /// `true` si la próxima vez que se muestre la pantalla principal,
  /// debe abrir automáticamente el bottom sheet de captura.
  bool _pendingOpenRequest = false;
  bool get pendingOpenRequest => _pendingOpenRequest;

  /// Inicializa el canal. Debe llamarse una sola vez desde `main()`.
  ///
  /// Devuelve `true` si la app fue abierta desde el Tile (cold-start).
  /// En ese caso, el flag `pendingOpenRequest` ya queda activado.
  Future<bool> init() async {
    // 1) Handler para eventos en vivo (app ya en foreground).
    _channel.setMethodCallHandler((call) async {
      if (call.method == _kOpenExpenseSheet) {
        _pendingOpenRequest = true;
        notifyListeners();
      }
    });

    // 2) Consulta el "initial intent" (caso cold-start).
    final opened = await _channel.invokeMethod<bool>('getInitialAction');
    if (opened == true) {
      _pendingOpenRequest = true;
      notifyListeners();
    }
    return opened == true;
  }

  /// Marca el pedido como consumido (ya abrimos el bottom sheet).
  void consumeOpenRequest() {
    if (_pendingOpenRequest) {
      _pendingOpenRequest = false;
      notifyListeners();
    }
  }

  /// Solicita cerrar la app (desde modo transparente/Tile).
  Future<void> finishApp() async {
    try {
      await _channel.invokeMethod<void>('finishApp');
    } on PlatformException {
      SystemNavigator.pop();
    }
  }

  /// Solicita el estado "listening" del Tile.
  Future<void> requestListeningState() async {
    try {
      await _channel.invokeMethod<void>('requestListeningState');
    } on PlatformException {
      // Ignoramos errores.
    }
  }
}
