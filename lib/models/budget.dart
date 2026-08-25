/// Modelo de presupuesto por categoría.
library;

enum BudgetPeriod { weekly, monthly }

class Budget {
  final String id;
  final String categoryName;
  final double amount;
  final BudgetPeriod period;

  const Budget({
    required this.id,
    required this.categoryName,
    required this.amount,
    required this.period,
  });

  factory Budget.create({
    required String categoryName,
    required double amount,
    required BudgetPeriod period,
  }) =>
      Budget(
        id: 'bgt-${DateTime.now().microsecondsSinceEpoch}',
        categoryName: categoryName,
        amount: amount,
        period: period,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryName': categoryName,
        'amount': amount,
        'period': period.name,
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        categoryName: json['categoryName'] as String,
        amount: (json['amount'] as num).toDouble(),
        period: BudgetPeriod.values.firstWhere(
          (p) => p.name == json['period'],
          orElse: () => BudgetPeriod.monthly,
        ),
      );

  Budget copyWith({String? categoryName, double? amount, BudgetPeriod? period}) =>
      Budget(
        id: id,
        categoryName: categoryName ?? this.categoryName,
        amount: amount ?? this.amount,
        period: period ?? this.period,
      );

  @override
  bool operator ==(Object other) => other is Budget && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
