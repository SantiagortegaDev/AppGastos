/// Notificaciones locales: recordatorio de registro y avisos de pago
/// detectado (usado también por el listener de notificaciones).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int reminderNotificationId = 1000;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Callback invocado cuando el usuario toca una notificación de pago
  /// detectado. Recibe el `payload` (id del pago pendiente a verificar).
  void Function(String payload)? onPaymentNotificationTap;

  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Si falla, se queda en UTC — el recordatorio igual dispara,
      // solo puede variar unas horas la hora exacta.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (response.id != reminderNotificationId && payload != null && payload.isNotEmpty) {
          onPaymentNotificationTap?.call(payload);
        }
      },
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _ready = true;
  }

  /// Programa (o cancela) el recordatorio de "no registraste en N días".
  /// Se debe volver a llamar cada vez que se guarda un registro nuevo, para
  /// reiniciar la cuenta desde ese momento.
  Future<void> scheduleRegisterReminder({required bool enabled, required int days}) async {
    await _plugin.cancel(reminderNotificationId);
    if (!enabled || days <= 0) return;

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(days: days));
    try {
      await _plugin.zonedSchedule(
        reminderNotificationId,
        'No registraste gastos',
        'Hace $days días que no anotás nada en AppGastos. Tocá para registrar.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Recordatorios',
            channelDescription: 'Recordatorio para registrar gastos e ingresos.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('No se pudo programar el recordatorio: $e');
    }
  }

  /// Notificación de "posible pago detectado", con diseño tipo recibo en el
  /// payload que abre la pantalla de verificación al tocarla.
  Future<void> showPaymentDetected({
    required int notificationId,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_detected_channel',
          'Pagos detectados',
          channelDescription: 'Avisa cuando se detecta un posible pago en otra app.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.recommendation,
        ),
      ),
      payload: payload,
    );
  }
}
