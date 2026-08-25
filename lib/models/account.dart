/// Modelo de una billetera (origen/destino del dinero).
library;

import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final int colorValue;
  final double balance;

  const Account({
    required this.id,
    required this.name,
    required this.colorValue,
    this.balance = 0.0,
  });

  Color get color => Color(colorValue);

  factory Account.create({
    required String name,
    required Color color,
    double balance = 0.0,
  }) =>
      Account(
        id: 'acc-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        colorValue: color.value,
        balance: balance,
      );

  Account copyWith({String? name, int? colorValue, double? balance}) => Account(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        balance: balance ?? this.balance,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorValue,
        'balance': balance,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: (json['color'] as num).toInt(),
        balance: json['balance'] != null
            ? (json['balance'] as num).toDouble()
            : 0.0,
      );

  @override
  bool operator ==(Object other) => other is Account && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

const List<Account> kDefaultAccounts = [
  Account(id: 'acc-cash', name: 'Efectivo', colorValue: 0xFF16A34A, balance: 0.0),
  Account(id: 'acc-bank', name: 'Banco', colorValue: 0xFF2563EB, balance: 0.0),
  Account(id: 'acc-card', name: 'Tarjeta', colorValue: 0xFF9333EA, balance: 0.0),
];
