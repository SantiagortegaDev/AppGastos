/// Regla de detección de pagos: qué app escuchar y qué debe contener la
/// notificación para considerarla un pago.
library;

class PaymentWatchRule {
  final String id;
  final String packageName;
  final String label;
  final List<String> keywords;
  final bool enabled;

  const PaymentWatchRule({
    required this.id,
    required this.packageName,
    required this.label,
    this.keywords = const [],
    this.enabled = true,
  });

  factory PaymentWatchRule.create({
    required String packageName,
    required String label,
    List<String> keywords = const [],
  }) =>
      PaymentWatchRule(
        id: 'pwr-${DateTime.now().microsecondsSinceEpoch}',
        packageName: packageName,
        label: label,
        keywords: keywords,
      );

  PaymentWatchRule copyWith({bool? enabled, List<String>? keywords}) => PaymentWatchRule(
        id: id,
        packageName: packageName,
        label: label,
        keywords: keywords ?? this.keywords,
        enabled: enabled ?? this.enabled,
      );

  /// JSON pensado para ser leído directamente por el
  /// NotificationListenerService nativo (Kotlin), no solo por Dart.
  Map<String, dynamic> toJson() => {
        'id': id,
        'packageName': packageName,
        'label': label,
        'keywords': keywords,
        'enabled': enabled,
      };

  factory PaymentWatchRule.fromJson(Map<String, dynamic> json) => PaymentWatchRule(
        id: json['id'] as String,
        packageName: json['packageName'] as String,
        label: json['label'] as String? ?? json['packageName'] as String,
        keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        enabled: json['enabled'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is PaymentWatchRule && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Apps comunes de pago en LatAm, para autocompletar rápido en Ajustes.
/// El paquete real puede variar por región; el usuario puede editarlo.
const List<(String label, String packageName)> kSuggestedPaymentApps = [
  ('Mercado Pago', 'com.mercadopago.wallet'),
  ('Nequi', 'com.nequi.MobileApp'),
  ('Daviplata', 'com.davivienda.daviplata'),
  ('Bancolombia', 'com.bancolombia.personas'),
  ('Nu', 'com.nu.production'),
  ('PayPal', 'com.paypal.android.p2pmobile'),
];
