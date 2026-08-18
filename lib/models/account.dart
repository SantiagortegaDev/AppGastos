/// Modelo de una "cuenta" (origen del dinero: efectivo, banco, tarjeta, etc.).
library;

import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final int colorValue; // Color.value

  const Account({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  factory Account.create({
    required String name,
    required Color color,
  }) =>
      Account(
        id: 'acc-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        colorValue: color.value,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorValue,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: (json['color'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) => other is Account && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Cuentas por defecto que se crean al primer arranque de la app.
/// El usuario puede editarlas/eliminarlas/añadir nuevas en Settings.
const List<Account> kDefaultAccounts = [
  Account(id: 'acc-cash', name: 'Efectivo', colorValue: 0xFF16A34A),
  Account(id: 'acc-bank', name: 'Banco', colorValue: 0xFF2563EB),
  Account(id: 'acc-card', name: 'Tarjeta', colorValue: 0xFF9333EA),
];
