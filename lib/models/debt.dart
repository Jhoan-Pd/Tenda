/// Factura pendiente de pago a un proveedor (deuda agendada).
class Debt {
  final int? id;
  final String supplier;
  final String description;

  /// Valor total de la factura (COP).
  final double totalAmount;

  /// Fecha límite para pagar.
  final DateTime dueDate;

  final DateTime createdAt;
  final bool paid;

  Debt({
    this.id,
    required this.supplier,
    this.description = '',
    required this.totalAmount,
    required this.dueDate,
    DateTime? createdAt,
    this.paid = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Debt copyWith({
    int? id,
    String? supplier,
    String? description,
    double? totalAmount,
    DateTime? dueDate,
    bool? paid,
  }) {
    return Debt(
      id: id ?? this.id,
      supplier: supplier ?? this.supplier,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      paid: paid ?? this.paid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier': supplier,
      'description': description,
      'totalAmount': totalAmount,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'paid': paid ? 1 : 0,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] as int?,
      supplier: map['supplier'] as String,
      description: (map['description'] as String?) ?? '',
      totalAmount: (map['totalAmount'] as num).toDouble(),
      dueDate: DateTime.parse(map['dueDate'] as String),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      paid: (map['paid'] as int? ?? 0) == 1,
    );
  }
}

/// Abono realizado a una deuda.
class DebtPayment {
  final int? id;
  final int debtId;
  final double amount;
  final DateTime date;

  DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtId': debtId,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'] as int?,
      debtId: map['debtId'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
    );
  }
}

/// Deuda con sus abonos y cálculos de plan de ahorro.
class DebtWithPayments {
  final Debt debt;
  final List<DebtPayment> payments;

  DebtWithPayments({required this.debt, required this.payments});

  double get totalPaid => payments.fold(0.0, (sum, p) => sum + p.amount);

  double get remaining => (debt.totalAmount - totalPaid).clamp(0, double.infinity);

  bool get isSettled => remaining <= 0 || debt.paid;

  int get daysUntilDue {
    final today = DateTime.now();
    final due = DateTime(debt.dueDate.year, debt.dueDate.month, debt.dueDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return due.difference(now).inDays;
  }

  bool get isOverdue => !isSettled && daysUntilDue < 0;

  bool get isDueSoon => !isSettled && daysUntilDue >= 0 && daysUntilDue <= 7;

  /// Cuánto hay que ahorrar cada día para pagar a tiempo.
  double get dailySaving {
    final days = daysUntilDue;
    if (days <= 0) return remaining;
    return remaining / days;
  }

  /// Cuánto hay que ahorrar cada semana para pagar a tiempo.
  double get weeklySaving {
    final days = daysUntilDue;
    if (days <= 7) return remaining;
    return remaining / (days / 7);
  }
}
