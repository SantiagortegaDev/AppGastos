/// Puente entre los TileServices nativos y Flutter.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String _kChannelName = 'appgastos.dev/tile';

class TileChannel extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel(_kChannelName);

  /// `true` si hay un pedido pendiente de abrir el modal.
  bool _pendingOpen = false;
  bool get hasPendingOpen => _pendingOpen;

  /// Tipo de transacción que pidió el tile.
  /// `null` = mostrar selección (tile "Registrar").
  /// `"gasto"` / `"ingreso"` = saltar selección.
  String? _pendingType;
  String? get pendingType => _pendingType;

  /// Inicializa el canal. Devuelve `true` si la app fue abierta desde un tile.
  Future<bool> init() async {
    // Handler para eventos en vivo (app ya corriendo).
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openExpenseSheet') {
        _pendingOpen = true;
        _pendingType = call.arguments as String?;
        notifyListeners();
      }
    });

    // Cold-start: consultar el intent inicial.
    final result = await _channel.invokeMethod<Map>('getInitialAction');
    if (result != null && result['open'] == true) {
      _pendingOpen = true;
      _pendingType = result['type'] as String?;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Consume el pedido pendiente y devuelve el tipo (o null para selección).
  String? consumeRequest() {
    if (!_pendingOpen) return null;
    final type = _pendingType;
    _pendingOpen = false;
    _pendingType = null;
    notifyListeners();
    // '' significa "mostrar selección", lo convertimos a null.
    return (type != null && type.isNotEmpty) ? type : null;
  }

  /// Cierra la app (usado después de registrar desde un tile).
  Future<void> finishApp() async {
    try {
      await _channel.invokeMethod<void>('finishApp');
    } on PlatformException {
      SystemNavigator.pop();
    }
  }

  /// Solicita actualizar el estado del tile.
  Future<void> requestListeningState() async {
    try {
      await _channel.invokeMethod<void>('requestListeningState');
    } on PlatformException {}
  }
}
