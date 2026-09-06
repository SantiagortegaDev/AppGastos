/// Puente entre los TileServices nativos y Flutter.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String _kChannelName = 'appgastos.dev/tile';

/// Datos de un pago detectado por `PaymentNotificationListenerService`.
class DetectedPayment {
  final String sourcePackage;
  final String sourceLabel;
  final String text;
  const DetectedPayment({required this.sourcePackage, required this.sourceLabel, required this.text});
}

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

  /// Pago detectado pendiente de verificar (si la app se abrió/está abierta
  /// por tocar la notificación de "posible pago detectado").
  DetectedPayment? _pendingPayment;
  bool get hasPendingPayment => _pendingPayment != null;

  /// Inicializa el canal. Devuelve `true` si la app fue abierta desde un tile.
  Future<bool> init() async {
    // Handler para eventos en vivo (app ya corriendo).
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openExpenseSheet') {
        _pendingOpen = true;
        _pendingType = call.arguments as String?;
        notifyListeners();
      } else if (call.method == 'paymentDetected') {
        final args = (call.arguments as Map).cast<String, dynamic>();
        _setPendingPayment(args);
      }
    });

    // Cold-start: consultar el intent inicial.
    final result = await _channel.invokeMethod<Map>('getInitialAction');
    if (result == null) return false;

    final payment = result['payment'];
    if (payment is Map) {
      _setPendingPayment(payment.cast<String, dynamic>());
    }

    if (result['open'] == true) {
      _pendingOpen = true;
      _pendingType = result['type'] as String?;
      notifyListeners();
      return true;
    }
    return _pendingPayment != null;
  }

  void _setPendingPayment(Map<String, dynamic> args) {
    final sourcePackage = args['sourcePackage'] as String? ?? '';
    final text = args['text'] as String? ?? '';
    if (sourcePackage.isEmpty || text.isEmpty) return;
    _pendingPayment = DetectedPayment(
      sourcePackage: sourcePackage,
      sourceLabel: (args['sourceLabel'] as String?)?.isNotEmpty == true ? args['sourceLabel'] as String : sourcePackage,
      text: text,
    );
    notifyListeners();
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

  /// Consume el pago pendiente de verificar.
  DetectedPayment? consumePendingPayment() {
    final payment = _pendingPayment;
    _pendingPayment = null;
    if (payment != null) notifyListeners();
    return payment;
  }

  /// Abre la pantalla del sistema para activar "Acceso a notificaciones".
  Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod<bool>('openNotificationListenerSettings');
    } on PlatformException {}
  }

  /// Si el usuario ya activó el permiso especial de acceso a notificaciones.
  Future<bool> isNotificationListenerEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
    } on PlatformException {
      return false;
    }
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
