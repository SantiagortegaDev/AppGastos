/// Puente entre el `TileService` nativo (Kotlin) y Flutter.
///
/// Flujo:
/// 1. El usuario toca el Tile en el panel de ajustes rápidos.
/// 2. `ExpenseTileService.kt` construye un `Intent` con el extra
///    `open_expense_sheet = true` y lanza `MainActivity`.
/// 3. `MainActivity.kt` reenvía ese evento a través de este canal usando
///    `method.invokeMethod("openExpenseSheet")` (caso app en foreground)
///    o almacena el flag para que Flutter lo consulte al arrancar
///    (caso app en cold-start) usando `getInitialAction()`.
///
/// Usamos un `ChangeNotifier` para que la UI pueda suscribirse a cambios.
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
  void init() {
    // 1) Handler para eventos en vivo (app ya en foreground).
    _channel.setMethodCallHandler((call) async {
      if (call.method == _kOpenExpenseSheet) {
        _pendingOpenRequest = true;
        notifyListeners();
      }
    });

    // 2) Consulta el "initial intent" (caso cold-start).
    //    MainActivity guarda el extra y lo responde aquí.
    _channel.invokeMethod<bool>('getInitialAction').then((opened) {
      if (opened == true) {
        _pendingOpenRequest = true;
        notifyListeners();
      }
    });
  }

  /// Marca el pedido como consumido (ya abrimos el bottom sheet).
  void consumeOpenRequest() {
    if (_pendingOpenRequest) {
      _pendingOpenRequest = false;
      notifyListeners();
    }
  }

  /// Solicita el estado "listening" del Tile (útil para refrescar el
  /// label/icono si cambia algo). Llama al lado Kotlin.
  Future<void> requestListeningState() async {
    try {
      await _channel.invokeMethod<void>('requestListeningState');
    } on PlatformException {
      // Ignoramos errores — el Tile seguirá funcionando.
    }
  }
}
