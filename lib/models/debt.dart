/// Modelo de una deuda: dinero que me deben o que yo debo.
library;

enum DebtDirection {
  owedToMe('Me deben'),
  iOwe('Yo debo');

  final String label;
  const DebtDirection(this.label);

  static DebtDirection fromName(String name) =>
      values.firstWhere((d) => d.name == name, orElse: () => DebtDirection.owedToMe);
}

class Debt {
  final String id;
  final String person;
  final double amount;
  final double paidAmount;
  final DebtDirection direction;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String note;

  const Debt({
    required this.id,
    required this.person,
    required this.amount,
    this.paidAmount = 0,
    required this.direction,
    required this.createdAt,
    this.dueDate,
    this.note = '',
  });

  factory Debt.create({
    required String person,
    required double amount,
    required DebtDirection direction,
    DateTime? dueDate,
    String note = '',
  }) =>
      Debt(
        id: 'debt-${DateTime.now().microsecondsSinceEpoch}',
        person: person,
        amount: amount,
        direction: direction,
        createdAt: DateTime.now(),
        dueDate: dueDate,
        note: note,
      );

  double get remaining => (amount - paidAmount).clamp(0, amount);
  bool get isSettled => remaining <= 0;
  bool get isOverdue => !isSettled && dueDate != null && dueDate!.isBefore(DateTime.now());

  Debt copyWith({double? paidAmount, DateTime? dueDate, String? note}) => Debt(
        id: id,
        person: person,
        amount: amount,
        paidAmount: paidAmount ?? this.paidAmount,
        direction: direction,
        createdAt: createdAt,
        dueDate: dueDate ?? this.dueDate,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'person': person,
        'amount': amount,
        'paidAmount': paidAmount,
        'direction': direction.name,
        'createdAt': createdAt.toIso8601String(),
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        if (note.isNotEmpty) 'note': note,
      };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
        id: json['id'] as String,
        person: json['person'] as String,
        amount: (json['amount'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        direction: DebtDirection.fromName(json['direction'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
        note: (json['note'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) => other is Debt && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
